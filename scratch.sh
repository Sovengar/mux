#!/bin/bash
# Interactive shell for a scratch overlay; exits with the shell, so the overlay
# closes on exit.
set -u
exec "${SHELL:-fish}"
