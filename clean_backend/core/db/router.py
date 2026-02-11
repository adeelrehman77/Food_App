import threading

# Thread-local storage for the current database alias
_thread_locals = threading.local()

def get_current_db_alias():
    """Get the current database alias from thread-local storage."""
    return getattr(_thread_locals, 'db_alias', 'default')

def set_current_db_alias(alias):
    """Set the current database alias in thread-local storage."""
    _thread_locals.db_alias = alias

class TenantRouter:
    """
    A router to control all database operations on models for different tenants.
    """

    def db_for_read(self, model, **hints):
        """
        Attempts to read models go to the tenant's database, 
        unless it's a shared app that must live in 'default'.
        """
        shared_apps = [
            'users', 'organizations', 'admin', 'auth', 'contenttypes', 
            'sessions', 'sites', 'account', 'socialaccount', 'authtoken', 
            'axes', 'django_apscheduler'
        ]
        if model._meta.app_label in shared_apps:
            return 'default'
        return get_current_db_alias()

    def db_for_write(self, model, **hints):
        """
        Attempts to write models go to the tenant's database,
        unless it's a shared app that must live in 'default'.
        """
        shared_apps = [
            'users', 'organizations', 'admin', 'auth', 'contenttypes', 
            'sessions', 'sites', 'account', 'socialaccount', 'authtoken', 
            'axes', 'django_apscheduler'
        ]
        if model._meta.app_label in shared_apps:
            return 'default'
        return get_current_db_alias()

    def allow_relation(self, obj1, obj2, **hints):
        """
        Allow relations if both objects are in the same database.
        """
        db1 = getattr(obj1, '_state', None)
        db2 = getattr(obj2, '_state', None)
        
        if db1 and db2 and db1.db and db2.db:
            return db1.db == db2.db
        return None

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        """
        Shared apps ONLY migrate to 'default'.
        Tenant-specific apps (functional apps) migrate to tenant databases,
        but we also allow them in 'default' so the global admin doesn't crash.
        """
        shared_apps = [
            'users', 'organizations', 'admin', 'auth', 'contenttypes', 
            'sessions', 'sites', 'account', 'socialaccount', 'authtoken', 
            'axes', 'django_apscheduler'
        ]
        
        if db == 'default':
            # Everything is allowed in default (fallback/admin view)
            return True
        
        # In tenant databases, we ONLY allow functional apps
        return app_label not in shared_apps
