# Change these variables to match your setup.
REMOTE_HOST ?= your-remote-host
REMOTE_DIR ?= /path/to/R2E-Gym
LOCAL_DIR ?= ../

push:
	rsync -avz --exclude=".venv" --exclude "logs" ./ $(REMOTE_HOST):$(REMOTE_DIR)

pull:
	rsync -avz --exclude='.arm64_build_contexts' --exclude='.arm64_repo_cache' --exclude='*.egg-info' --exclude='.venv' --exclude='__pycache__' $(REMOTE_HOST):$(REMOTE_DIR) $(LOCAL_DIR)
