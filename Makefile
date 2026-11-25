DBT = cd olist_dbt && dbt
ARGS = --profiles-dir .

.PHONY: all up data load build docs reports clean

all: up data load build reports

up:            ## start PostgreSQL
	docker compose up -d --wait

data:          ## download the Olist CSV files
	python3 scripts/download_data.py

load:          ## load raw CSV into schema raw
	python3 scripts/load_raw.py

build:         ## run all dbt models + tests
	$(DBT) build $(ARGS)

docs:          ## generate and serve dbt documentation (lineage graph)
	$(DBT) docs generate $(ARGS) && $(DBT) docs serve $(ARGS)

reports:       ## compile analyses, export CSV + charts
	$(DBT) compile $(ARGS) --select "resource_type:analysis"
	python3 scripts/export_reports.py

clean:
	docker compose down -v
