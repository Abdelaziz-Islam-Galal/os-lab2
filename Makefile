.PHONY: run_antivirus run_restore

run_antivirus:
	@mkdir -p "malicious_dir"
	@./antivirusd.sh dir malicious_dir 2

run_restore:
	@./restore.sh dir malicious_dir

