#!/bin/bash
# Infrastructure Validation Script
# This script validates the Terraform infrastructure for security, cost optimization, and compliance.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "Starting infrastructure validation..."

# Check if required tools are installed
check_tools() {
  echo "Checking required tools..."
  
  # Check Terraform
  if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed.${NC}"
    exit 1
  fi
  
  # Check AWS CLI
  if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed.${NC}"
    exit 1
  }
  
  # Check tfsec if available
  if ! command -v tfsec &> /dev/null; then
    echo -e "${YELLOW}Warning: tfsec is not installed. Security checks will be limited.${NC}"
    TFSEC_AVAILABLE=false
  else
    TFSEC_AVAILABLE=true
  fi
  
  # Check checkov if available
  if ! command -v checkov &> /dev/null; then
    echo -e "${YELLOW}Warning: checkov is not installed. Compliance checks will be limited.${NC}"
    CHECKOV_AVAILABLE=false
  else
    CHECKOV_AVAILABLE=true
  fi
  
  echo -e "${GREEN}Tool check completed.${NC}"
}

# Validate Terraform configuration
validate_terraform() {
  echo "Validating Terraform configuration..."
  
  # Initialize Terraform
  terraform init
  
  # Check formatting
  if ! terraform fmt -check -recursive; then
    echo -e "${RED}Error: Terraform files are not properly formatted.${NC}"
    echo "Run 'terraform fmt -recursive' to fix formatting issues."
    exit 1
  fi
  
  # Validate configuration
  if ! terraform validate; then
    echo -e "${RED}Error: Terraform validation failed.${NC}"
    exit 1
  fi
  
  echo -e "${GREEN}Terraform validation passed.${NC}"
}

# Check for security issues
check_security() {
  echo "Checking for security issues..."
  
  # Use tfsec if available
  if [ "$TFSEC_AVAILABLE" = true ]; then
    echo "Running tfsec..."
    if ! tfsec .; then
      echo -e "${RED}Error: Security issues found by tfsec.${NC}"
      SECURITY_ISSUES=true
    fi
  fi
  
  # Manual security checks
  echo "Running manual security checks..."
  
  # Check for public S3 buckets
  if grep -r "acl\s*=\s*\"public-read\"" --include="*.tf" .; then
    echo -e "${RED}Error: Public S3 buckets detected.${NC}"
    SECURITY_ISSUES=true
  fi
  
  # Check for unrestricted security groups
  if grep -r "cidr_blocks\s*=\s*\[\s*\"0.0.0.0/0\"\s*\]" --include="*.tf" .; then
    echo -e "${YELLOW}Warning: Unrestricted security group rules detected.${NC}"
    SECURITY_ISSUES=true
  fi
  
  # Check for unencrypted resources
  if ! grep -r "encrypt\s*=\s*true" --include="*.tf" . | grep -q "s3"; then
    echo -e "${YELLOW}Warning: S3 buckets might not be encrypted.${NC}"
    SECURITY_ISSUES=true
  fi
  
  if [ "$SECURITY_ISSUES" = true ]; then
    echo -e "${RED}Security checks failed. Please address the issues above.${NC}"
  else
    echo -e "${GREEN}Security checks passed.${NC}"
  fi
}

# Check for cost optimization
check_cost() {
  echo "Checking for cost optimization..."
  
  # Check for expensive instance types
  if grep -r "instance_type\s*=\s*\".*\.large\"" --include="*.tf" .; then
    echo -e "${YELLOW}Warning: Large instance types detected. Consider using smaller instances or Spot instances.${NC}"
    COST_ISSUES=true
  fi
  
  # Check for provisioned IOPS
  if grep -r "iops" --include="*.tf" .; then
    echo -e "${YELLOW}Warning: Provisioned IOPS detected. Ensure this is necessary for your workload.${NC}"
    COST_ISSUES=true
  fi
  
  # Check for lifecycle rules on S3
  if ! grep -r "lifecycle_rule" --include="*.tf" . | grep -q "s3"; then
    echo -e "${YELLOW}Warning: S3 buckets might not have lifecycle rules for cost optimization.${NC}"
    COST_ISSUES=true
  fi
  
  if [ "$COST_ISSUES" = true ]; then
    echo -e "${YELLOW}Cost optimization checks found potential issues. Review the warnings above.${NC}"
  else
    echo -e "${GREEN}Cost optimization checks passed.${NC}"
  fi
}

# Check for compliance
check_compliance() {
  echo "Checking for compliance..."
  
  # Use checkov if available
  if [ "$CHECKOV_AVAILABLE" = true ]; then
    echo "Running checkov..."
    if ! checkov -d .; then
      echo -e "${RED}Error: Compliance issues found by checkov.${NC}"
      COMPLIANCE_ISSUES=true
    fi
  fi
  
  # Manual compliance checks
  echo "Running manual compliance checks..."
  
  # Check for tagging
  if ! grep -r "tags" --include="*.tf" .; then
    echo -e "${YELLOW}Warning: Resources might not be properly tagged.${NC}"
    COMPLIANCE_ISSUES=true
  fi
  
  # Check for logging
  if ! grep -r "logging" --include="*.tf" . | grep -q "s3"; then
    echo -e "${YELLOW}Warning: S3 buckets might not have logging enabled.${NC}"
    COMPLIANCE_ISSUES=true
  fi
  
  if [ "$COMPLIANCE_ISSUES" = true ]; then
    echo -e "${YELLOW}Compliance checks found potential issues. Review the warnings above.${NC}"
  else
    echo -e "${GREEN}Compliance checks passed.${NC}"
  fi
}

# Generate report
generate_report() {
  echo "Generating validation report..."
  
  REPORT_FILE="validation_report_$(date +%Y%m%d_%H%M%S).txt"
  
  echo "Infrastructure Validation Report" > "$REPORT_FILE"
  echo "Date: $(date)" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  echo "Terraform Validation: ${TERRAFORM_STATUS}" >> "$REPORT_FILE"
  echo "Security Checks: ${SECURITY_STATUS}" >> "$REPORT_FILE"
  echo "Cost Optimization: ${COST_STATUS}" >> "$REPORT_FILE"
  echo "Compliance Checks: ${COMPLIANCE_STATUS}" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  
  if [ "$SECURITY_ISSUES" = true ] || [ "$COST_ISSUES" = true ] || [ "$COMPLIANCE_ISSUES" = true ]; then
    echo "Issues were found during validation. Please review the logs for details." >> "$REPORT_FILE"
    echo -e "${YELLOW}Validation completed with warnings. Report saved to ${REPORT_FILE}${NC}"
  else
    echo "No issues were found during validation." >> "$REPORT_FILE"
    echo -e "${GREEN}Validation completed successfully. Report saved to ${REPORT_FILE}${NC}"
  fi
}

# Main function
main() {
  # Initialize variables
  SECURITY_ISSUES=false
  COST_ISSUES=false
  COMPLIANCE_ISSUES=false
  
  # Run checks
  check_tools
  
  # Change to terraform directory if script is run from project root
  if [ -d "terraform" ] && [ ! -f "main.tf" ]; then
    cd terraform
  fi
  
  validate_terraform
  TERRAFORM_STATUS=$([[ $? -eq 0 ]] && echo "PASSED" || echo "FAILED")
  
  check_security
  SECURITY_STATUS=$([[ "$SECURITY_ISSUES" = false ]] && echo "PASSED" || echo "FAILED")
  
  check_cost
  COST_STATUS=$([[ "$COST_ISSUES" = false ]] && echo "PASSED" || echo "WARNING")
  
  check_compliance
  COMPLIANCE_STATUS=$([[ "$COMPLIANCE_ISSUES" = false ]] && echo "PASSED" || echo "WARNING")
  
  generate_report
  
  # Exit with error if any critical checks failed
  if [ "$TERRAFORM_STATUS" = "FAILED" ] || [ "$SECURITY_STATUS" = "FAILED" ]; then
    exit 1
  fi
  
  exit 0
}

# Run the main function
main