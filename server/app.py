import os
from flask import Flask, request, jsonify
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
    student_id = request.json.get('student_id')
    password = request.json.get('password')

    if student_id and password:
        pass
    else:
        return jsonify({'message': 'Missing Credentials'}), 400