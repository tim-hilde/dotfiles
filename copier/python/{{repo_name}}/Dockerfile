FROM python:3.12-slim-bookworm AS base
COPY --from=ghcr.io/astral-sh/uv:0.9.2 /uv /uvx /bin/

# Enable bytecode compilation
ENV UV_COMPILE_BYTECODE=1

# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy

FROM base AS dependencies
WORKDIR /home/worker/app
COPY pyproject.toml uv.lock readme.md ./

RUN --mount=type=cache,target=/root/.cache/uv \
	--mount=type=bind,source=uv.lock,target=uv.lock \
	--mount=type=bind,source=pyproject.toml,target=pyproject.toml \
	uv sync --frozen --no-install-project --no-dev --no-editable

COPY ./src/ src

RUN --mount=type=cache,target=/root/.cache/uv \
	uv sync --locked --no-editable --no-dev

FROM base AS app
ENV PYTHONUNBUFFERED=1
EXPOSE 8001

ARG UID=1000

# Define the Group ID (GID) for the non-root user
# GID 65534 is often used for the 'nogroup' or 'nobody' group
ARG GID=65534

RUN adduser --system --gid ${GID} --uid ${UID} --home /home/worker worker
WORKDIR /home/worker/app

RUN chown worker /home/worker/app
COPY --chown=worker --from=dependencies /home/worker/app/.venv/ .venv
COPY --chown=worker src/ src

USER worker

CMD []
