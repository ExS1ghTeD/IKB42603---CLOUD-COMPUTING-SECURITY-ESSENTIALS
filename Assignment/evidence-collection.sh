#!/usr/bin/env bash
# MediPay compliance evidence collection - IKB42603

export EP='--endpoint-url=http://localhost:4566'
BUCKET='medipay-patient-records'
OUT="evidence-$(date +%Y%m%d).txt"
LS_CONTAINER=$(docker ps -qf "ancestor=localstack/localstack")

{
echo "MediPay technical evidence pack"
echo "Collected: $(date -u) by Syed"

echo "=== IAM-05 Least privilege on execution roles ==="
aws $EP iam list-role-policies --role-name patient-lookup-role --output json

echo "=== IVS Tenant isolation & segmentation ==="
aws $EP s3api get-bucket-policy --bucket $BUCKET --query 'Policy' --output text | jq .

echo "=== CEK-03 Encryption at rest ==="
aws $EP s3api get-bucket-encryption --bucket $BUCKET \
--query 'ServerSideEncryptionConfiguration.Rules[0]' --output json

echo "=== DSP-04 Data classification ==="
aws $EP s3api get-object-tagging --bucket $BUCKET --key confidential/record.txt

echo "=== LOG-07 / LOG-02 Management plane audit trail ==="
docker logs "$LS_CONTAINER" 2>&1 | grep -E "AWS [a-z0-9]+\.[A-Za-z]+ =>" > mgmt-trail.log
wc -l mgmt-trail.log
sha256sum mgmt-trail.log > mgmt-trail.sha256
aws $EP s3 cp mgmt-trail.sha256 s3://miit-audit-trail/

echo "=== AIS-06 Pipeline security gate ==="
bash ci-gate.sh > /dev/null 2>&1
echo "gate exit code: $? (0 = policy satisfied, 1 = blocked)"

echo "=== DSP-17 Public exposure guardrail ==="
aws $EP s3api get-public-access-block --bucket $BUCKET \
--query 'PublicAccessBlockConfiguration' --output json

echo "=== DSP-16 Retention and disposal ==="
aws $EP s3api get-bucket-lifecycle-configuration --bucket $BUCKET \
--query 'Rules[].[ID, Status]' --output json

} | tee "$OUT"
sha256sum "$OUT"
