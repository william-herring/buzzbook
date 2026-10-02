import json

from models import db, Institution, Building, Room, User

FEATURE_COLUMNS = {
    "Chairs": "chairs",
    "Tables": "tables",
    "Whiteboard": "whiteboards",
    "TV": "televisions",
    "Projector": "projectors",
    "Powerpoints": "powerpoints",
}


def _get_or_create(model, lookup, **values):
    obj = model.query.filter_by(**lookup).first()
    created = obj is None
    if created:
        obj = model(**lookup)
        db.session.add(obj)
    for key, value in values.items():
        setattr(obj, key, value)
    return obj, created


def populate_from_file(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    counts = {"institutions": 0, "buildings": 0, "rooms": 0, "users": 0}

    try:
        institution, created = _get_or_create(
            Institution,
            {"name": data["name"]},
            latitude=data.get("latitude"),
            longitude=data.get("longitude"),
        )
        db.session.flush()
        counts["institutions"] += created

        buildings = {}
        for room in data["rooms"]:
            name = str(room["building"])
            if name not in buildings:
                buildings[name], created = _get_or_create(
                    Building, {"institution_id": institution.id, "name": name}
                )
                counts["buildings"] += created
        db.session.flush()

        for room in data["rooms"]:
            features = room.get("features", {})
            _, created = _get_or_create(
                Room,
                {"building_id": buildings[str(room["building"])].id, "name": room["name"]},
                floor=int(room["floor"]),
                room_type=room.get("room_type"),
                capacity=room.get("capacity", 0),
                **{col: features.get(key, 0) for key, col in FEATURE_COLUMNS.items()},
            )
            counts["rooms"] += created

        for student in data["students"]:
            user, created = _get_or_create(
                User,
                {"student_id": student["student_id"]},
                institution_id=institution.id,
                email=student["email"],
            )
            if created:
                user.set_password(student["password"])
            counts["users"] += created

        db.session.commit()
    except Exception:
        db.session.rollback()
        raise

    return counts