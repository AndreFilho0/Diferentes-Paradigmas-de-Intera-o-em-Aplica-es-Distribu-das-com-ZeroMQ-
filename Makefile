SHELL := /bin/bash
TF    := infra/terraform
ANS   := infra/ansible

.DEFAULT_GOAL := help

help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-18s\033[0m %s\n",$$1,$$2}'

# ----------------------------- Local (sem AWS) -----------------------------

setup: ## Cria o venv local e instala o pyzmq
	python3 -m venv .venv
	.venv/bin/pip install --quiet --upgrade pip
	.venv/bin/pip install --quiet -r requirements.txt
	@echo "venv pronto. Rode: make demo-local"

demo-local: ## Roda os 3 paradigmas na propria maquina (localhost)
	bash scripts/demo-local.sh

# ------------------------------- AWS (infra) -------------------------------

init: ## terraform init (uma vez)
	terraform -chdir=$(TF) init

up: ## Cria as instancias EC2 (terraform apply)
	terraform -chdir=$(TF) apply -auto-approve

provision: ## Instala e configura tudo nas instancias (ansible)
	cd $(ANS) && ansible-playbook playbook.yml

deploy: up provision commands ## Cria + provisiona + imprime os comandos

commands: ## Imprime os comandos prontos para rodar cada paradigma
	bash scripts/print-commands.sh

ssh-coordinator: ## Abre um SSH no coordenador
	ssh -i $$(terraform -chdir=$(TF) output -raw ssh_key) \
		-o StrictHostKeyChecking=no \
		ec2-user@$$(terraform -chdir=$(TF) output -raw coordinator_public_ip)

down: ## DESTROI toda a infra (use sempre ao terminar, para nao gastar credito)
	terraform -chdir=$(TF) destroy -auto-approve

check: ## Valida Terraform (fmt/validate) e Ansible (syntax-check)
	terraform -chdir=$(TF) fmt -check
	terraform -chdir=$(TF) validate
	cd $(ANS) && ansible-playbook playbook.yml --syntax-check

.PHONY: help setup demo-local init up provision deploy commands ssh-coordinator down check
