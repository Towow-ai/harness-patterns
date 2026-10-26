# Deleting things

- In code you write, delete directories with
  `guarded_rmtree` from `tools/guarded.py`, never with a
  bare `shutil.rmtree`. Single files outside protected
  directories can be deleted normally.
- In the shell, delete directories with
  `python3 tools/guarded.py <path>`.
- A directory holding a `.do-not-delete` file is never
  deleted. If it is in your way, stop and ask the human.
