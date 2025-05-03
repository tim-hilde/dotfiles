FROM python:3.12-slim-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends \
	build-essential \
	g++ \
	python3-dev \
	libffi-dev \
	curl \
	&& rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.6.9 /uv /uvx /bin/

# Enable bytecode compilation
ENV UV_COMPILE_BYTECODE=1

# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy

WORKDIR /app
COPY .python-version pyproject.toml uv.lock README.md /app/

RUN --mount=type=cache,target=/root/.cache/uv \
	--mount=type=bind,source=uv.lock,target=uv.lock \
	--mount=type=bind,source=pyproject.toml,target=pyproject.toml \
	uv sync --frozen --no-install-project --no-dev

COPY ./{{package_name}} /app/{{package_name}}/
COPY ./static /app/static/

RUN --mount=type=cache,target=/root/.cache/uv \
	uv sync --frozen --no-dev

# place executables in the environment at the front of the path
ENV PATH="/app/.venv/bin:$PATH"

# Reset the entrypoint, don't invoke `uv`
ENTRYPOINT []

# TODO: Add Command
CMD []

# TODO: Expose port
EXPOSE
