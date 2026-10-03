import functools
import hmac
import json
import os
import secrets

from flask import Response, flash, redirect, render_template_string, request, session, url_for
from sqlalchemy.exc import IntegrityError

from models import db, Institution, Building, Room, User
from util import populate_from_data

PAGE = """
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Buzzbook admin</title>
  <style>
    body { font-family: system-ui, sans-serif; background: #f6f4fb; color: #222; margin: 0; }
    main { max-width: 760px; margin: 0 auto; padding: 24px 16px 64px; }
    h1 { margin-bottom: 4px; }
    h2 { margin-top: 36px; }
    .card { background: #fff; border-radius: 8px; padding: 16px 20px; box-shadow: 0 1px 4px rgba(0,0,0,.08); }
    button { background: #512da8; color: #fff; border: 0; border-radius: 4px; padding: 8px 16px; font-size: 15px; cursor: pointer; }
    table { width: 100%; border-collapse: collapse; }
    th, td { text-align: left; padding: 8px 6px; border-bottom: 1px solid #eee; }
    th { color: #666; font-weight: 600; font-size: 13px; }
    .msg { padding: 10px 14px; border-radius: 4px; }
    .ok { background: #e8f5e9; color: #1b5e20; }
    .error { background: #ffebee; color: #b71c1c; }
    .hint { color: #666; font-size: 14px; }
  </style>
</head>
<body>
<main>
  <h1>Buzzbook admin</h1>

  {% for category, message in get_flashed_messages(with_categories=true) %}
    <p class="msg {{ category }}">{{ message }}</p>
  {% endfor %}

  <h2>Add an institution</h2>
  <div class="card">
    <p class="hint">
      Upload a JSON file shaped like <code>rmit_institution.json</code>
      (<code>name</code>, <code>buildings</code>, <code>users</code>, <code>rooms</code>).
      If an institution with the same name already exists it is updated instead.
    </p>
    <form method="post" action="{{ url_for('admin_upload') }}" enctype="multipart/form-data">
      <input type="hidden" name="csrf" value="{{ csrf }}">
      <input type="file" name="file" accept=".json,application/json" required>
      <button type="submit">Upload</button>
    </form>
  </div>

  <h2>Institutions</h2>
  <div class="card">
    {% if institutions %}
    <table>
      <tr><th>ID</th><th>Name</th><th>Buildings</th><th>Rooms</th><th>Users</th></tr>
      {% for i in institutions %}
      <tr>
        <td>{{ i.id }}</td><td>{{ i.name }}</td>
        <td>{{ i.buildings }}</td><td>{{ i.rooms }}</td><td>{{ i.users }}</td>
      </tr>
      {% endfor %}
    </table>
    {% else %}
      <p class="hint">No institutions yet.</p>
    {% endif %}
  </div>
</main>
</body>
</html>
"""


def admin_required(view):
    @functools.wraps(view)
    def wrapped(*args, **kwargs):
        username = os.getenv('ADMIN_USERNAME')
        password = os.getenv('ADMIN_PASSWORD')
        if not username or not password:
            return ('Admin dashboard is turned off. Set ADMIN_USERNAME and '
                    'ADMIN_PASSWORD in server/.env to turn it on.'), 503

        auth = request.authorization
        valid = (
            auth is not None
            and hmac.compare_digest((auth.username or '').encode(), username.encode())
            and hmac.compare_digest((auth.password or '').encode(), password.encode())
        )
        if not valid:
            return Response('Login required', 401,
                            {'WWW-Authenticate': 'Basic realm="Buzzbook admin"'})
        return view(*args, **kwargs)
    return wrapped


def institution_rows():
    rows = []
    for inst in Institution.query.order_by(Institution.id).all():
        rooms = (
            Room.query
            .join(Building, Room.building_id == Building.id)
            .filter(Building.institution_id == inst.id)
            .count()
        )
        rows.append({
            'id': inst.id,
            'name': inst.name,
            'buildings': Building.query.filter_by(institution_id=inst.id).count(),
            'rooms': rooms,
            'users': User.query.filter_by(institution_id=inst.id).count(),
        })
    return rows


def register_admin(app):
    app.config.setdefault('MAX_CONTENT_LENGTH', 2 * 1024 * 1024)

    @app.route('/admin', methods=['GET'])
    @admin_required
    def admin_home():
        csrf = session.setdefault('csrf', secrets.token_hex(16))
        return render_template_string(PAGE, csrf=csrf, institutions=institution_rows())

    @app.route('/admin/upload', methods=['POST'])
    @admin_required
    def admin_upload():
        expected = session.get('csrf')
        sent = request.form.get('csrf', '')
        if not expected or not hmac.compare_digest(sent.encode(), expected.encode()):
            flash('That form expired. Please try again.', 'error')
            return redirect(url_for('admin_home'))

        file = request.files.get('file')
        if file is None or not file.filename:
            flash('Choose a JSON file first.', 'error')
            return redirect(url_for('admin_home'))

        try:
            data = json.load(file.stream)
            counts = populate_from_data(data, source=file.filename)
        except json.JSONDecodeError as e:
            flash(f"That file isn't valid JSON ({e}).", 'error')
        except ValueError as e:
            flash(str(e), 'error')
        except KeyError as e:
            flash(f'The file is missing a field: {e}', 'error')
        except IntegrityError:
            flash('A student ID or email in the file is already used by someone else. '
                  'Nothing was saved.', 'error')
        except Exception:
            app.logger.exception('Institution upload failed')
            flash('Something went wrong and nothing was saved. Check the server log.', 'error')
        else:
            added = ', '.join(
                f'{counts[key]} {key}' for key in ('buildings', 'rooms', 'users') if counts[key]
            )
            verb = 'Created' if counts['institutions'] else 'Updated'
            detail = f'added {added}.' if added else 'nothing new to add.'
            flash(f"{verb} {data['name']}: {detail}", 'ok')

        return redirect(url_for('admin_home'))