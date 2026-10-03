import os
from datetime import datetime, timezone

from flask import Flask, request, jsonify
from flask_jwt_extended import create_access_token, JWTManager, jwt_required, get_jwt_identity, get_jwt
from flask_migrate import Migrate
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import and_, func, or_
from sqlalchemy.exc import IntegrityError

from models import *
from util import haversine_metres, find_current_booking, iso_utc, as_utc
from scheduler import start_scheduler, NO_SHOW_GRACE

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY')
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URI')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY')
jwt = JWTManager(app)
db.init_app(app)
migrate = Migrate(app, db)

with app.app_context():
    db.create_all()
    db.session.commit()

start_scheduler(app)

@jwt.token_in_blocklist_loader
def is_token_revoked(jwt_header, jwt_payload):
    return TokenBlocklist.query.filter_by(jti=jwt_payload['jti']).first() is not None

@app.route('/authenticate', methods=['POST'])
def authenticate():
    institution_id = request.json.get('institution_id')
    student_id = request.json.get('student_id')
    password = request.json.get('password')

    user = User.query.filter_by(institution_id=institution_id, student_id=student_id).first()
    if not user or not user.check_password(password):
        return jsonify({'message': 'Invalid Credentials'}), 401

    token = create_access_token(identity=str(user.id))
    print("Valid request for user with id " + str(user.id))
    return jsonify({'access_token': token, 'token_type': 'bearer'}), 200

@app.route('/get-rooms', methods=['GET'])
@jwt_required()
def get_rooms():
    user_id = get_jwt_identity()
    user = User.query.filter_by(id=user_id).first()
    building_name = request.args.get('building_name')
    status = request.args.get('status')

    institution_id = user.institution_id
    if building_name:
        buildings = Building.query.filter_by(institution_id=institution_id, name=building_name).all()
    else:
        buildings = Building.query.filter_by(institution_id=institution_id).all()

    result = []

    for building in buildings:
        filters = {'building_id': building.id}
        if status:
            filters['status'] = status
        rooms = Room.query.filter_by(**filters).all()
        for room in rooms:
            result.append({
                'id': room.id,
                'name': room.name,
                'building_id': building.id,
                'floor': room.floor,
                'room_type': room.room_type,
                'capacity': room.capacity,
                'chairs': room.chairs,
                'tables': room.tables,
                'whiteboards': room.whiteboards,
                'televisions': room.televisions,
                'projectors': room.projectors,
                'powerpoints': room.powerpoints,
                'latitude': room.latitude,
                'longitude': room.longitude,
            })

    return jsonify(result)

@app.route('/get-buildings', methods=['GET'])
@jwt_required()
def get_all_buildings():
    user_id = get_jwt_identity()
    user = User.query.filter_by(id=user_id).first()

    institution_id = user.institution_id
    buildings = Building.query.filter_by(institution_id=institution_id).all()
    result = []
    for building in buildings:
        result.append({
            'id': building.id,
            'name': building.name,
            'latitude': building.latitude,
            'longitude': building.longitude,
        })

    return jsonify(result)

def parse_time(value):
    if not isinstance(value, str):
        raise ValueError("must be an ISO 8601 string")
    dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if dt.tzinfo is None:
        raise ValueError("must include a UTC offset, e.g. 2026-10-05T14:00:00+11:00")
    return dt.astimezone(timezone.utc)


@app.route('/book-room', methods=['POST'])
@jwt_required()
def book_room():
    user_id = get_jwt_identity()
    user = User.query.filter_by(id=user_id).first()

    data = request.get_json()

    try:
        start = parse_time(data['start_time'])
        end = parse_time(data['end_time'])
    except ValueError as e:
        return jsonify({'message': f'Invalid time: {e}'}), 400
    if end <= start:
        return jsonify({'message': 'end_time must be after start_time'}), 400
    if start < datetime.now(timezone.utc):
        return jsonify({'message': 'Cannot book a time in the past'}), 400

    user_ids = data.get('user_ids', [])
    student_ids = data.get('student_ids', [])
    if (not isinstance(user_ids, list) or not all(isinstance(i, int) for i in user_ids)
            or not isinstance(student_ids, list)
            or not all(isinstance(s, str) for s in student_ids)):
        return jsonify({'message': 'user_ids must be a list of integers and '
                                   'student_ids a list of strings'}), 400

    participants = {user.id: user}
    if user_ids:
        for u in User.query.filter(User.id.in_(user_ids)).all():
            participants[u.id] = u
    wanted = {s.strip().lower() for s in student_ids}
    if wanted:
        for u in User.query.filter(func.lower(User.student_id).in_(wanted)).all():
            participants[u.id] = u

    unknown = [str(i) for i in sorted(set(user_ids) - participants.keys())]
    unknown += sorted(wanted - {u.student_id.lower() for u in participants.values()})
    if unknown:
        return jsonify({'message': f"Users not found: {', '.join(unknown)}"}), 404
    participant_ids = set(participants)

    room = Room.query.filter_by(id=data['room_id']).with_for_update().first()
    if not room:
        return jsonify({'message': 'Room not found'}), 404
    if room.status not in (None, 'available', 'occupied'):
        return jsonify({'message': f'Room is not bookable (status: {room.status})'}), 409

    overlaps = and_(Booking.start_time < end, Booking.end_time > start)

    if Booking.query.filter(Booking.room_id == room.id, overlaps).first():
        return jsonify({'message': 'Room is already booked for that time'}), 409

    busy = User.query.filter(
        User.id.in_(participant_ids), User.bookings.any(overlaps)
    ).all()
    if busy:
        ids = ', '.join(u.student_id for u in busy)
        return jsonify({'message': f'Already booked at that time: {ids}'}), 409

    booking = Booking(room_id=room.id, start_time=start, end_time=end, users=list(participants.values()))
    db.session.add(booking)
    try:
        db.session.commit()
    except IntegrityError:
        db.session.rollback()
        return jsonify({'message': 'Room is already booked for that time'}), 409

    return jsonify({
        'booking_id': booking.id,
        'room_id': room.id,
        'room_name': room.name,
        'start_time': start.isoformat(),
        'end_time': end.isoformat(),
        'user_ids': sorted(participant_ids),
    }), 201

@app.route('/room/<int:room_id>', methods=['GET'])
def get_room(room_id):
    room = Room.query.filter_by(id=room_id).first()
    if not room:
        return jsonify({'message': 'Room not found'}), 404
    building = db.session.get(Building, room.building_id) if room.building_id else None
    upcoming = (
        Booking.query
        .filter(Booking.room_id == room.id, Booking.end_time > datetime.now(timezone.utc))
        .order_by(Booking.start_time)
        .all()
    )
    data = {
        'id': room.id,
        'name': room.name,
        'status': room.status,
        'floor': room.floor,
        'room_type': room.room_type,
        'capacity': room.capacity,
        'latitude': room.latitude,
        'longitude': room.longitude,
        'features': {
            'chairs': room.chairs,
            'tables': room.tables,
            'whiteboards': room.whiteboards,
            'televisions': room.televisions,
            'projectors': room.projectors,
            'powerpoints': room.powerpoints,
        },
        'building': None if building is None else {
            'id': building.id,
            'name': building.name,
            'latitude': building.latitude,
            'longitude': building.longitude,
        },
        'bookings': [{
            'id': b.id,
            'start_time': iso_utc(b.start_time),
            'end_time': iso_utc(b.end_time),
            'student_ids': [u.student_id for u in b.users],
        } for b in upcoming],
    }

    return jsonify(data), 200

def get_room_id_arg():
    try:
        return int(request.args.get('room_id'))
    except (TypeError, ValueError):
        return None


@app.route('/room-sign-in', methods=['POST'])
@jwt_required()
def room_sign_in():
    user_id = get_jwt_identity()
    user = User.query.filter_by(id=user_id).first()
    if not user:
        return jsonify({'message': 'User not found'}), 401

    room_id = get_room_id_arg()
    if room_id is None:
        return jsonify({'message': 'room_id must be an integer'}), 400

    room = Room.query.filter_by(id=room_id).with_for_update().first()
    if not room:
        return jsonify({'message': 'Room not found'}), 404

    now = datetime.now(timezone.utc)
    booking = find_current_booking(user.id, room.id, now)
    if not booking:
        return jsonify({'message': 'You have no booking for this room right now'}), 403

    room.occupied_now = True
    db.session.commit()

    return jsonify({
        'message': 'Signed in',
        'room_id': room.id,
        'booking_id': booking.id,
        'ends_at': iso_utc(booking.end_time),
    }), 200


@app.route('/room-sign-out', methods=['POST'])
@jwt_required()
def room_sign_out():
    user_id = get_jwt_identity()
    user = User.query.filter_by(id=user_id).first()
    if not user:
        return jsonify({'message': 'User not found'}), 401

    room_id = get_room_id_arg()
    if room_id is None:
        return jsonify({'message': 'room_id must be an integer'}), 400

    room = Room.query.filter_by(id=room_id).with_for_update().first()
    if not room:
        return jsonify({'message': 'Room not found'}), 404

    now = datetime.now(timezone.utc)
    booking = find_current_booking(user.id, room.id, now)
    if not booking:
        return jsonify({'message': 'You have no booking for this room right now'}), 403

    booking_id = booking.id
    room.occupied_now = False
    room.status = 'available'
    db.session.delete(booking)
    db.session.commit()

    return jsonify({
        'message': 'Signed out',
        'room_id': room.id,
        'booking_id': booking_id,
    }), 200


@app.route('/rooms-near-me', methods=['GET'])
@jwt_required()
def get_rooms_near_me():
    user_id = get_jwt_identity()
    user = User.query.filter_by(id=user_id).first()
    if not user:
        return jsonify({'message': 'User not found'}), 401

    try:
        latitude = float(request.args['latitude'])
        longitude = float(request.args['longitude'])
        radius = float(request.args.get('radius', 500))
    except (KeyError, ValueError):
        return jsonify({'message': 'latitude and longitude are required numbers; '
                                   'radius (metres) must be a number'}), 400
    if not (-90 <= latitude <= 90 and -180 <= longitude <= 180) or radius <= 0:
        return jsonify({'message': 'Coordinates or radius out of range'}), 400

    now = datetime.now(timezone.utc)
    rows = (
        db.session.query(Room, Building)
        .join(Building, Room.building_id == Building.id)
        .filter(
            Building.institution_id == user.institution_id,
            or_(Room.status.is_(None), Room.status == 'available'),
            Room.occupied_now.is_not(True),
            ~Room.bookings.any(and_(Booking.start_time <= now, Booking.end_time > now)),
        )
        .all()
    )

    results = []
    for room, building in rows:
        room_lat = room.latitude if room.latitude is not None else building.latitude
        room_lon = room.longitude if room.longitude is not None else building.longitude
        if room_lat is None or room_lon is None:
            continue
        distance = haversine_metres(latitude, longitude, room_lat, room_lon)
        if distance > radius:
            continue
        results.append({
            'id': room.id,
            'name': room.name,
            'building_id': building.id,
            'building_name': building.name,
            'floor': room.floor,
            'room_type': room.room_type,
            'capacity': room.capacity,
            'latitude': room_lat,
            'longitude': room_lon,
            'distance_metres': round(distance),
        })

    results.sort(key=lambda r: r['distance_metres'])
    return jsonify(results), 200


@app.route('/add-to-booking', methods=['POST'])
@jwt_required()
def add_to_booking():
    user_id = get_jwt_identity()
    user = User.query.filter_by(id=user_id).first()
    if not user:
        return jsonify({'message': 'User not found'}), 401

    data = request.get_json(silent=True) or {}
    booking_id = data.get('booking_id')
    invited_student_id = data.get('invited_user_id')
    if not isinstance(booking_id, int) or not isinstance(invited_student_id, str) \
            or not invited_student_id.strip():
        return jsonify({'message': 'booking_id (integer) and invited_user_id '
                                   '(student ID string) are required'}), 400

    booking = Booking.query.filter_by(id=booking_id).with_for_update().first()
    if not booking:
        return jsonify({'message': 'Booking not found'}), 404
    if user not in booking.users:
        return jsonify({'message': 'You are not part of this booking'}), 403
    if as_utc(booking.end_time) <= datetime.now(timezone.utc):
        return jsonify({'message': 'This booking has already ended'}), 409

    invited = User.query.filter(
        func.lower(User.student_id) == invited_student_id.strip().lower()
    ).first()
    if not invited:
        return jsonify({'message': f'Student {invited_student_id.strip()} not found'}), 404
    if invited in booking.users:
        return jsonify({'message': f'{invited.student_id} is already in this booking'}), 409

    room = db.session.get(Room, booking.room_id)
    if room and room.capacity and len(booking.users) >= room.capacity:
        return jsonify({'message': f'Room is at capacity ({room.capacity})'}), 409

    clash = Booking.query.filter(
        Booking.users.any(User.id == invited.id),
        and_(Booking.start_time < booking.end_time, Booking.end_time > booking.start_time),
    ).first()
    if clash:
        return jsonify({'message': f'{invited.student_id} is already booked at that time'}), 409

    booking.users.append(invited)
    db.session.commit()

    return jsonify({
        'message': f'{invited.student_id} added to booking',
        'booking_id': booking.id,
        'users': [{'id': u.id, 'student_id': u.student_id} for u in booking.users],
    }), 200


@app.route('/logout', methods=['POST'])
@jwt_required()
def logout():
    db.session.add(TokenBlocklist(jti=get_jwt()['jti']))
    db.session.commit()
    return jsonify({'message': 'Logged out'}), 200


@app.route('/me', methods=['GET'])
@jwt_required()
def me():
    user = db.session.get(User, int(get_jwt_identity()))
    if not user:
        return jsonify({'message': 'User not found'}), 401

    institution = db.session.get(Institution, user.institution_id) if user.institution_id else None
    return jsonify({
        'id': user.id,
        'student_id': user.student_id,
        'email': user.email,
        'institution': None if institution is None else {
            'id': institution.id,
            'name': institution.name,
        },
    }), 200


@app.route('/room-booking-status', methods=['GET'])
@jwt_required()
def room_booking_status():
    user = db.session.get(User, int(get_jwt_identity()))
    if not user:
        return jsonify({'message': 'User not found'}), 401

    room_id = get_room_id_arg()
    if room_id is None:
        return jsonify({'message': 'room_id must be an integer'}), 400

    room = db.session.get(Room, room_id)
    if not room:
        return jsonify({'message': 'Room not found'}), 404

    now = datetime.now(timezone.utc)
    booking = find_current_booking(user.id, room.id, now)
    if booking and not room.occupied_now and now >= as_utc(booking.start_time) + NO_SHOW_GRACE:
        booking = None

    return jsonify({
        'room': {'id': room.id, 'name': room.name},
        'booking': None if booking is None else {
            'id': booking.id,
            'start_time': iso_utc(booking.start_time),
            'end_time': iso_utc(booking.end_time),
            'signed_in': bool(room.occupied_now),
        },
    }), 200