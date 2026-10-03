import json
import io
import zipfile
from datetime import timezone
from math import radians, sin, asin, sqrt, cos

import qrcode
from qrcode.constants import ERROR_CORRECT_M

from models import db, Institution, Building, Room, User, Booking

FEATURE_COLUMNS = {
    "Chairs": "chairs",
    "Tables": "tables",
    "Whiteboard": "whiteboards",
    "TV": "televisions",
    "Projector": "projectors",
    "Powerpoints": "powerpoints",
}

DEFAULT_PREFIX = "buzzbook://room/"


def _get_or_create(model, lookup, **values):
    obj = model.query.filter_by(**lookup).first()
    created = obj is None
    if created:
        obj = model(**lookup)
        db.session.add(obj)
    for key, value in values.items():
        setattr(obj, key, value)
    return obj, created


def _clean_outline(building_name, outline):
    valid = (
        isinstance(outline, list)
        and len(outline) >= 3
        and all(
            isinstance(p, (list, tuple))
            and len(p) == 2
            and all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in p)
            and -90 <= p[0] <= 90
            and -180 <= p[1] <= 180
            for p in outline
        )
    )
    if not valid:
        raise ValueError(
            f"The outline for {building_name} must be a list of at least 3 "
            f"[latitude, longitude] pairs"
        )
    return [[float(lat), float(lng)] for lat, lng in outline]


def populate_from_file(path):
    with open(path, encoding="utf-8") as f:
        return populate_from_data(json.load(f), source=path)


def populate_from_data(data, source="the data"):
    if not isinstance(data, dict):
        raise ValueError(f"{source} must contain a JSON object, not a list or a single value")

    for key in ("name", "buildings", "users", "rooms"):
        if key not in data:
            raise ValueError(f"'{key}' missing from {source}")

    building_defs = {str(b["building_id"]): b for b in data["buildings"]}
    undefined = sorted({str(r["building"]) for r in data["rooms"]} - building_defs.keys())
    if undefined:
        raise ValueError(f"Rooms reference undefined buildings: {', '.join(undefined)}")

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
        for building_id, b in building_defs.items():
            extra = {}
            if b.get("outline") is not None:
                extra["outline"] = _clean_outline(b["name"], b["outline"])
            buildings[building_id], created = _get_or_create(
                Building,
                {"institution_id": institution.id, "name": b["name"]},
                latitude=b.get("latitude"),
                longitude=b.get("longitude"),
                **extra,
            )
            counts["buildings"] += created
        db.session.flush()

        for room in data["rooms"]:
            building = buildings[str(room["building"])]
            features = room.get("features", {})
            _, created = _get_or_create(
                Room,
                {"building_id": building.id, "name": room["name"]},
                floor=int(room["floor"]),
                room_type=room.get("room_type"),
                capacity=room.get("capacity", 0),
                latitude=room.get("latitude", building.latitude),
                longitude=room.get("longitude", building.longitude),
                **{col: features.get(key, 0) for key, col in FEATURE_COLUMNS.items()},
            )
            counts["rooms"] += created

        for u in data["users"]:
            existing = User.query.filter_by(student_id=u["student_id"]).first()
            if existing and existing.institution_id not in (None, institution.id):
                raise ValueError(
                    f"Student {u['student_id']} already belongs to a different institution"
                )
            user, created = _get_or_create(
                User,
                {"student_id": u["student_id"]},
                institution_id=institution.id,
                email=u["email"],
            )
            if created:
                user.set_password(u["password"])
            counts["users"] += created

        db.session.commit()
    except Exception:
        db.session.rollback()
        raise

    return counts


def generate_room_qr_zip(institution_id, output_path, prefix=DEFAULT_PREFIX):
    rooms = (
        Room.query
        .join(Building, Room.building_id == Building.id)
        .filter(Building.institution_id == institution_id)
        .order_by(Building.name, Room.name)
        .add_columns(Building.name)
        .all()
    )
    if not rooms:
        raise ValueError(f"No rooms found for institution {institution_id}")

    with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as archive:
        for room, building_name in rooms:
            qr = qrcode.QRCode(error_correction=ERROR_CORRECT_M, box_size=12, border=4)
            qr.add_data(f"{prefix}{room.id}")
            qr.make(fit=True)

            buffer = io.BytesIO()
            qr.make_image(fill_color="black", back_color="white").save(buffer, format="PNG")
            archive.writestr(f"{building_name}/{room.name}.png", buffer.getvalue())

    return len(rooms)

def iso_utc(dt):
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).isoformat()

def as_utc(dt):
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)

def haversine_metres(lat1, lon1, lat2, lon2):
    p1, p2 = radians(lat1), radians(lat2)
    a = sin((p2 - p1) / 2) ** 2 + cos(p1) * cos(p2) * sin(radians(lon2 - lon1) / 2) ** 2
    return 2 * 6371000 * asin(sqrt(a))


def find_current_booking(user_id, room_id, now):
    return Booking.query.filter(
        Booking.room_id == room_id,
        Booking.start_time <= now,
        Booking.end_time > now,
        Booking.users.any(User.id == user_id),
    ).first()