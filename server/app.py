import os
from datetime import datetime, timezone

from flask import Flask, request, jsonify
from flask_jwt_extended import create_access_token, JWTManager, jwt_required, get_jwt_identity
from flask_migrate import Migrate
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import and_, func
from sqlalchemy.exc import IntegrityError

from models import *

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

@app.route('/authenticate', methods=['POST'])
def authenticate():
    institution_id = request.json.get('institution_id')
    student_id = request.json.get('student_id')
    password = request.json.get('password')

    user = User.query.filter_by(institution_id=institution_id, student_id=student_id).first()
    if not user or not user.check_password(password):
        return jsonify({'message': 'Invalid Credentials'}), 401

    token = create_access_token(identity=user.id)
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
        rooms = Room.query.filter_by(building_id=building.id, status=status).all()
        for room in rooms:
            room.append({
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
    if room.status not in (None, 'available'):
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

@app.route('/room/<room_id>', methods=['GET'])
def get_room(room_id):
    room = Room.query.filter_by(id=room_id).first()
    if not room:
        return jsonify({'message': 'Room not found'}), 404
    building = Building.query.filter(id=room.building_id) if room.building_id else None
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
    }

    return jsonify(data), 200