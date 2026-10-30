#!/bin/bash

DATABASE_NAME="cs2102_project"
CMD="psql -U postgres -d${DATABASE_NAME} -f"
create_db() {
	$CMD triggers.sql
}

drop_db() {
	$CMD drop_schema.sql
}

test_db() {
	$CMD test.sql
}

drop_db
create_db
test_db
