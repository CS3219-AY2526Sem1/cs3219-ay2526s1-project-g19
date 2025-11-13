import asyncio
from logging.config import fileConfig

from sqlalchemy import pool
from sqlalchemy.ext.asyncio import create_async_engine
from alembic import context
from sqlmodel import SQLModel
from models.session import *
from config import settings

# Alembic Config object
config = context.config

# Setup Python logging
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Metadata for 'autogenerate'
target_metadata = SQLModel.metadata

# ------------------------
# Offline migrations
# ------------------------
def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode (no DB connection)."""
    url = settings.pg_url.replace("+asyncpg", "+psycopg2")  # offline needs sync driver
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()

# ------------------------
# Online migrations
# ------------------------
async def run_migrations_online() -> None:
    """Run migrations in 'online' mode with AsyncEngine."""
    connectable = create_async_engine(settings.pg_url, poolclass=pool.NullPool)

    async with connectable.begin() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()

def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()

# ------------------------
# Entrypoint
# ------------------------
if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
