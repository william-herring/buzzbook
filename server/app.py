import os
from flask import Flask, request, jsonify
from flask_jwt_extended import create_access_token, JWTManager, jwt_required, get_jwt_identity
from flask_migrate import Migrate
from flask_sqlalchemy import SQLAlchemy

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
@jwt_required
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

@jwt_required
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