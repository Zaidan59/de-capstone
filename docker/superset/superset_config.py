import os
SECRET_KEY = os.environ.get('SUPERSET_SECRET_KEY')
SQLALCHEMY_DATABASE_URI = 'sqlite:////app/superset_home/superset.db'
WTF_CSRF_ENABLED = True
ENABLE_PROXY_FIX = False
# Local Docker lab only. For any external deployment configure HTTPS and a real metadata DB.
