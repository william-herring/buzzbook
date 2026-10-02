from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash

db = SQLAlchemy()

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    institution_id = db.Column(db.Integer, db.ForeignKey('institution.id'))
    email = db.Column(db.String(120), unique=True, nullable=False)
    student_id = db.Column(db.String(50), unique=True, nullable=False)
    password_hash = db.Column(db.String(200), nullable=False)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class Institution(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String)
    latitude = db.Column(db.Float)
    longitude = db.Column(db.Float)

class Building(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String)
    institution_id = db.Column(db.Integer, db.ForeignKey('institution.id'))
    latitude = db.Column(db.Float)
    longitude = db.Column(db.Float)

class Room(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String)
    building_id = db.Column(db.Integer, db.ForeignKey('building.id'))
    floor = db.Column(db.Integer)
    room_type = db.Column(db.String)
    capacity = db.Column(db.Integer)
    chairs = db.Column(db.Integer)
    tables = db.Column(db.Integer)
    whiteboards = db.Column(db.Integer)
    televisions = db.Column(db.Integer)
    projectors = db.Column(db.Integer)
    powerpoints = db.Column(db.Integer)
    latitude = db.Column(db.Float)
    longitude = db.Column(db.Float)
