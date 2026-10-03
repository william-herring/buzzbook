import os
from datetime import datetime, timedelta, timezone

from apscheduler.schedulers.background import BackgroundScheduler
from flask.helpers import get_debug_flag
from sqlalchemy import or_

from models import db, Booking, Room
from util import as_utc

NO_SHOW_GRACE = timedelta(minutes=15)
INTERVAL_SECONDS = 30


def update_room_states():
    now = datetime.now(timezone.utc)

    active = Booking.query.filter(
        Booking.start_time <= now, Booking.end_time > now
    ).all()
    occupied_room_ids = set()

    for booking in active:
        room = Room.query.filter_by(id=booking.room_id).with_for_update().first()
        if room is None:
            continue

        no_show = not room.occupied_now and now >= as_utc(booking.start_time) + NO_SHOW_GRACE
        if no_show:
            db.session.delete(booking)
            continue

        occupied_room_ids.add(room.id)
        if room.status in (None, 'available'):
            room.status = 'occupied'

    stale = Room.query.filter(
        or_(Room.status == 'occupied', Room.occupied_now.is_(True))
    ).all()
    for room in stale:
        if room.id in occupied_room_ids:
            continue
        if room.status == 'occupied':
            room.status = 'available'
        room.occupied_now = False

    db.session.commit()


def start_scheduler(app):
    if get_debug_flag() and os.environ.get('WERKZEUG_RUN_MAIN') != 'true':
        return None

    def job():
        with app.app_context():
            try:
                update_room_states()
            except Exception:
                db.session.rollback()
                app.logger.exception('Room state update failed')

    scheduler = BackgroundScheduler(daemon=True)
    scheduler.add_job(job, 'interval', seconds=INTERVAL_SECONDS,
                      max_instances=1, coalesce=True)
    scheduler.start()
    return scheduler