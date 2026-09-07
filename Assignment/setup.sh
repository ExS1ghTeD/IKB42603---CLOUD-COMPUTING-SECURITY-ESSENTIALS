#!/usr/bin/env bash
# MediPay compliance lab - environment setup - IKB42603
# Run this after every LocalStack restart, BEFORE evidence-collection.sh.
# It recreates the bucket, role, policies, and lifecycle rules that
# LocalStack loses when the container stops (persistence disabled).

set -e  # stop immediately if any command fails, so you notice right away

export EP='--endpoint-url=http://localhost:4566'
BUCKET='medipay-patient-records'
AUDIT_BUCKET='miit-audit-trail'

echo "=== Creating buckets ==="
aws $EP s3 mb s3://$BUCKET
aws $EP s3 mb s3://$AUDIT_BUCKET

echo "=== Creating test patient record ==="
echo "test patient record" > record.txt
aws $EP s3 cp record.txt s3://$BUCKET/confidential/record.txt

echo "=== CEK-03: applying encryption ==="
cat > encryption.json << 'EOF'
{
  "Rules": [
    {
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms"
      }
    }
  ]
}
EOF
aws $EP s3api put-bucket-encryption --bucket $BUCKET \
  --server-side-encryption-configuration file://encryption.json

echo "=== DSP-04: tagging the record as confidential ==="
cat > tagging.json << 'EOF'
{
  "TagSet": [
    {
      "Key": "classification",
      "Value": "confidential"
    }
  ]
}
EOF
aws $EP s3api put-object-tagging --bucket $BUCKET \
  --key confidential/record.txt --tagging file://tagging.json

echo "=== IAM-05: creating role and least-privilege policy ==="
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
aws $EP iam create-role --role-name patient-lookup-role \
  --assume-role-policy-document file://trust-policy.json

cat > least-privilege.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::medipay-patient-records",
        "arn:aws:s3:::medipay-patient-records/confidential/*"
      ]
    }
  ]
}
EOF
aws $EP iam put-role-policy --role-name patient-lookup-role \
  --policy-name PatientLookupReadOnly --policy-document file://least-privilege.json

echo "=== IVS: applying tenant-isolation bucket policy ==="
cat > tenant-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnforceTenantIsolation",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::medipay-patient-records/confidential/*",
      "Condition": {
        "StringNotEquals": {
          "s3:ExistingObjectTag/TenantID": "${aws:PrincipalTag/TenantID}"
        }
      }
    }
  ]
}
EOF
aws $EP s3api put-bucket-policy --bucket $BUCKET --policy file://tenant-policy.json

echo "=== DSP-17: blocking public access ==="
aws $EP s3api put-public-access-block --bucket $BUCKET \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "=== DSP-16: applying 90-day retention/lifecycle rule ==="
cat > lifecycle.json << 'EOF'
{
  "Rules": [
    {
      "ID": "AutoDelete90Days",
      "Filter": {
        "Prefix": "confidential/"
      },
      "Status": "Enabled",
      "Expiration": {
        "Days": 90
      }
    }
  ]
}
EOF
aws $EP s3api put-bucket-lifecycle-configuration --bucket $BUCKET \
  --lifecycle-configuration file://lifecycle.json

echo "=== AIS-06: creating CI security gate script ==="
cat > ci-gate.sh << 'EOF'
#!/usr/bin/env bash
# Simulating a security scan (e.g., tfsec or checkov)
# 0 = pass, 1 = fail
exit 0
EOF
chmod +x ci-gate.sh

echo ""
echo "=== Setup complete. All resources recreated. ==="
echo "You can now run: ./evidence-collection.sh"
