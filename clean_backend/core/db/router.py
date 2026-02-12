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
    Database router for per-tenant-per-database multi-tenancy.

    Routing rules
    ─────────────
    1. **SaaS-level apps** always read/write from the ``default`` database.
       These contain platform-wide data: Tenant records, ServicePlans,
       SaaS admin sessions, login-throttling, scheduled jobs, etc.

    2. **All other apps** (including ``auth``, ``contenttypes``, ``sessions``,
       ``account``, ``authtoken``, and every tenant business app) follow the
       **current tenant context**.  When a request carries a tenant header,
       the middleware sets the thread-local DB alias to that tenant's database;
       these apps then read/write there.  When there is no tenant context
       (e.g. a SaaS admin using Django admin), they fall back to ``default``.

    Why ``auth`` follows tenant context
    ────────────────────────────────────
    Each tenant database has its own ``auth_user`` table (``allow_migrate``
    returns True for all DBs).  Tenant staff / customers are created inside
    the tenant DB.  This means ``DailyMenu.created_by = FK(User)`` and
    ``CustomerProfile.user = OneToOneField(User)`` are same-database
    references — no cross-DB FK hacks needed.

    SaaS-level superusers live in the ``default`` auth_user table and are
    used only through Django admin (no tenant header → default DB).
    """

    # Apps whose models are platform-wide and must always live in `default`.
    SAAS_ONLY_APPS = frozenset([
        'organizations',   # ServicePlan, etc.
        'users',           # Tenant, Domain, UserProfile (SaaS user-tenant mapping)
        'admin',           # Django admin (SaaS owner panel)
        'sites',           # Django sites framework
        'axes',            # Login throttling (global)
        'django_apscheduler',  # Scheduled jobs (global)
    ])

    def db_for_read(self, model, **hints):
        if model._meta.app_label in self.SAAS_ONLY_APPS:
            return 'default'
        return get_current_db_alias()

    def db_for_write(self, model, **hints):
        if model._meta.app_label in self.SAAS_ONLY_APPS:
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
        Allow all apps to migrate on all databases.

        Every tenant DB gets full schema (including auth_user, etc.)
        so that ForeignKey constraints are valid within each database.
        """
        return True
