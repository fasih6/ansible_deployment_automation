.PHONY: help install setup deploy check lint clean

help:
	@echo "Available commands:"
	@echo "  make install      - Install Ansible collections and Python dependencies"
	@echo "  make setup        - Run only setup tasks (packages, maven, docker)"
	@echo "  make deploy       - Run full deployment"
	@echo "  make check        - Run playbook in check mode (dry-run)"
	@echo "  make lint         - Lint Ansible playbooks"
	@echo "  make clean        - Clean cache and temporary files"
	@echo "  make inventory    - Display inventory graph"

install:
	@echo "Installing Ansible collections..."
	ansible-galaxy collection install -r requirements.yml
	
setup:
	ansible-playbook site.yaml --ask-vault-pass --tags "setup"

deploy:
	ansible-playbook site.yaml --ask-vault-pass

check:
	ansible-playbook site.yaml --ask-vault-pass --check

lint:
	ansible-lint site.yaml roles/deploy_app/tasks/main.yaml

clean:
	rm -rf /tmp/aws_ec2_inventory_cache/
	rm -rf /tmp/ansible_facts/
	find . -name "*.retry" -delete

inventory:
	ansible-inventory -i inventory/aws_ec2.yaml --graph

test-connection:
	ansible all -i inventory/aws_ec2.yaml -m ping -u ubuntu
