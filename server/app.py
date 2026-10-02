import os
from flask import Flask, request, jsonify
from flask_jwt_extended import create_access_token
from flask_migrate import Migrate
from flask_sqlalchemy import SQLAlchemy

from models import *

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY')
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URI')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)
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
    return jsonify({'access_token': token, 'token_type': 'bearer'}), 200
