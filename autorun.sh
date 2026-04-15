#!bin/bash 

# This script is used to run the application when the container starts.
bundle exec rackup -p 4444 &&
cd  attack && bundle exec rackup -p 4445 &&
cd ..
cd proxy && bundle exec rackup -p 4446 &&