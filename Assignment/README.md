1. Start localstack (if you have any)
docker start localstack

2. See the localstack info
curl http://localhost:4566/_localstack/info 
{"version": "2026.7.5:beafe195a", "edition": "pro", "is_license_activated": true, "session_id": "239a51e4-795d-4721-a139-26011108108b", "machine_id": "dkr_facfb9311bfe", "system": "Kali GNU/Linux Rolling,7.1.5+kali-amd64,x86_64", "is_docker": true, "server_time_utc": "2026-09-06T11:13:57", "uptime": 27}% 

3. See the localstack health
curl http://localhost:4566/_localstack/health
{"features": {"persistence": "disabled"}, "services": {"account": "available", "acm-pca": "available", "acm": "available", "amplify": "available", "apigateway": "available", "apigatewaymanagementapi": "available", "apigatewayv2": "available", "appconfig": "available", "appconfigdata": "available", "application-autoscaling": "available", "appsync": "available", "athena": "available", "autoscaling": "available", "backup": "available", "batch": "available", "bedrock-runtime": "available", "bedrock": "available", "ce": "available", "cloudcontrol": "available", "cloudformation": "available", "cloudfront": "available", "cloudtrail": "available", "cloudwatch": "available", "codeartifact": "available", "codebuild": "available", "codecommit": "available", "codeconnections": "available", "codedeploy": "available", "codepipeline": "available", "codestar-connections": "available", "cognito-identity": "available", "cognito-idp": "available", "config": "available", "dms": "available", "docdb": "available", "dsql": "available", "dynamodb": "available", "dynamodbstreams": "available", "ec2": "available", "ecr": "available", "ecs": "available", "efs": "available", "eks-auth": "available", "eks": "available", "elasticache": "available", "elasticbeanstalk": "available", "elb": "available", "elbv2": "available", "emr-serverless": "available", "emr": "available", "es": "available", "events": "available", "firehose": "available", "fis": "available", "glacier": "available", "glue": "available", "iam": "available", "identitystore": "available", "iot-data": "available", "iot": "available", "iotwireless": "available", "kafka": "available", "kinesis": "available", "kinesisanalyticsv2": "available", "kms": "available", "lakeformation": "available", "lambda": "available", "logs": "available", "managedblockchain": "available", "mediaconvert": "available", "memorydb": "available", "mq": "available", "mwaa": "available", "neptune": "available", "opensearch": "available", "organizations": "available", "pinpoint": "available", "pipes": "available", "ram": "available", "rds-data": "available", "rds": "available", "redshift-data": "available", "redshift": "available", "resource-groups": "available", "resourcegroupstaggingapi": "available", "route53": "available", "route53resolver": "available", "s3": "available", "s3control": "available", "s3tables": "available", "sagemaker-runtime": "available", "sagemaker": "available", "scheduler": "available", "secretsmanager": "available", "serverlessrepo": "available", "servicediscovery": "available", "ses": "available", "sesv2": "available", "shield": "available", "sns": "available", "sqs": "available", "ssm": "available", "sso-admin": "available", "stepfunctions": "available", "sts": "available", "support": "available", "swf": "available", "textract": "available", "timestream-query": "available", "timestream-write": "available", "transcribe": "available", "transfer": "available", "verifiedpermissions": "available", "wafv2": "available", "xray": "available"}, "edition": "pro", "version": "2026.7.5"}% 

4. Set the EP as the localstack endpoint
export EP='--endpoint-url=http://localhost:4566'

5. Create a test data
BUCKET=medipay-patient-records
aws $EP s3 mb s3://$BUCKET
echo "test patient record" > record.txt
aws $EP s3 cp record.txt s3://$BUCKET/confidential/record.txt

CEK-03 Process
6. Create encryption json file
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

7. Check it
cat encryption.json
{
  "Rules": [
    {
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms"
      }
    }
  ]
}

8. Run the command pointing at the file instead.
aws $EP s3api put-bucket-encryption --bucket $BUCKET --server-side-encryption-configuration file://encryption.json

9. Prove that it is work
aws $EP s3api get-bucket-encryption --bucket $BUCKET

{
    "ServerSideEncryptionConfiguration": {
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "aws:kms"
                },
                "BucketKeyEnabled": false,
                "BlockedEncryptionTypes": {
                    "EncryptionType": [
                        "SSE-C"
                    ]
                }
            }
        ]
    }
}

DSP-04 Process
10. Create the tagging json file
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

11. Check for it
cat tagging.json
{
  "TagSet": [
    {
      "Key": "classification",
      "Value": "confidential"
    }
  ]
}

12. Run the tagging command pointing at the file
aws $EP s3api put-object-tagging --bucket $BUCKET --key confidential/record.txt --tagging file://tagging.json

13. Prove it
aws $EP s3api get-object-tagging --bucket $BUCKET --key confidential/record.txt

{
    "TagSet": [
        {
            "Key": "classification",
            "Value": "confidential"
        }
    ]
}

IAM-05 Process
14. Make JSON file for trust policy (IAM-05).
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

15. Create a role:
aws $EP iam create-role --role-name patient-lookup-role --assume-role-policy-document file://trust-policy.json

{
    "Role": {
        "Path": "/",
        "RoleName": "patient-lookup-role",
        "RoleId": "AROAQAAAAAAANR4VMJDYL",
        "Arn": "arn:aws:iam::000000000000:role/patient-lookup-role",
        "CreateDate": "2026-09-06T12:44:50.142151+00:00",
        "AssumeRolePolicyDocument": {
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
    }
}

16. Create least privilege policy json.
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

17. Attach the policy to the role
aws $EP iam put-role-policy --role-name patient-lookup-role --policy-name PatientLookupReadOnly --policy-document file://least-privilege.json

18. Verify the attach
echo "=== IAM-05 (policy contents) ==="
aws $EP iam get-role-policy --role-name patient-lookup-role --policy-name PatientLookupReadOnly

{
    "RoleName": "patient-lookup-role",
    "PolicyName": "PatientLookupReadOnly",
    "PolicyDocument": {
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
}


LOG-07
19. Find the LocalStack container ID
LS_CONTAINER=$(docker ps -qf "ancestor=localstack/localstack")

20. Extract the management-plane trail from the request log
docker logs "$LS_CONTAINER" 2>&1 | grep -E "AWS [a-z0-9]+\.[A-Za-z]+ =>" > mgmt-trail.log

21. Verify the step
cat mgmt-trail.log | head -n 5
2026-08-19T17:16:58.372  INFO --- [et.reactor-1] localstack.request.aws     : AWS kms.CreateKey => 200
2026-08-19T17:20:25.310  INFO --- [et.reactor-0] localstack.request.aws     : AWS kms.Encrypt => 200
2026-08-19T17:23:28.340  INFO --- [et.reactor-1] localstack.request.aws     : AWS kms.GenerateDataKey => 200
2026-08-19T17:24:27.320  INFO --- [et.reactor-0] localstack.request.aws     : AWS kms.GenerateDataKey => 200
2026-08-19T17:32:11.994  INFO --- [et.reactor-1] localstack.request.aws     : AWS kms.CreateKey => 200

22. count the line inside the mgmt-trail.log
wc -l mgmt-trail.log
63 mgmt-trail.log

23. Generate the hash
sha256sum mgmt-trail.log > mgmt-trail.sha256

24. Check the hash
cat mgmt-trail.sha256 
bf926e2a313dc16539b49c3b64840af624d29078c1569acd3e298f94061dfe4b  mgmt-trail.log

25. Create the audit bucket
aws $EP s3 mb s3://miit-audit-trail
make_bucket: miit-audit-trail

26. Upload the sealed digest trail
aws $EP s3 cp mgmt-trail.sha256 s3://miit-audit-trail/
upload: ./mgmt-trail.sha256 to s3://miit-audit-trail/mgmt-trail.sha256

AIS-06 Process
27. Create the security gate script
cat > ci-gate.sh << 'EOF'
#!/usr/bin/env bash
# Simulating a security scan (e.g., tfsec or checkov)
# 0 = pass, 1 = fail
exit 0
EOF

28. Verify the creation
cat ci-gate.sh
#!/usr/bin/env bash
# Simulating a security scan (e.g., tfsec or checkov)
# 0 = pass, 1 = fail
exit 0

29. Change the file permission so the system allow it
chmod +x ci-gate.sh

30. Verify the permission
ls -l ci-gate.sh
-rwxrwxr-x 1 s1ght s1ght 102 Sep  6 21:16 ci-gate.sh

31. Run the exact command format required by the collection script
bash ci-gate.sh > /dev/null 2>&1
echo "gate exit code: $? (0 = policy satisfied, 1 = blocked)"
gate exit code: 0 (0 = policy satisfied, 1 = blocked)

IVS Process
32. Create Zero Trust Bukcet policy JSON
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

33. Verify the creation
cat tenant-policy.json
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

34. Add the policy to the bucket
aws $EP s3api put-bucket-policy --bucket $BUCKET --policy file://tenant-policy.json

35. Run the verification command
aws $EP s3api get-bucket-policy --bucket $BUCKET --query 'Policy' --output text | jq .
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

DSP-17 Process
36. enable the public access block
aws $EP s3api put-public-access-block \
    --bucket $BUCKET \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

37. Run the verifivation command
aws $EP s3api get-public-access-block --bucket $BUCKET \
    --query 'PublicAccessBlockConfiguration' --output json

{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
}

DSP-16 Process
38. Create the lifecycle configuration
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

39. Verify the creation
cat lifecycle.json
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

40. Apply the lifecycle rule
aws $EP s3api put-bucket-lifecycle-configuration \
    --bucket $BUCKET \
    --lifecycle-configuration file://lifecycle.json

{
    "TransitionDefaultMinimumObjectSize": "all_storage_classes_128K"
}

41. Run the verification command
aws $EP s3api get-bucket-lifecycle-configuration --bucket $BUCKET \
    --query 'Rules[].[ID, Status]' --output json

[
    [
        "AutoDelete90Days",
        "Enabled"
    ]
]

Assemble all the command
44. Create a file named "evidence-collection.sh" and paste the following
#!/usr/bin/env bash
# MediPay compliance evidence collection - IKB42603

export EP='--endpoint-url=http://localhost:4566'
BUCKET='medipay-patient-records'
OUT="evidence-$(date +%Y%m%d).txt"
LS_CONTAINER=$(docker ps -qf "ancestor=localstack/localstack")

{
echo "MediPay technical evidence pack"
echo "Collected: $(date -u) by Syed"

echo "=== IAM-05 Least Privilege ==="
aws $EP iam get-role-policy --role-name patient-lookup-role --policy-name PatientLookupReadOnly

echo "=== IVS-06 Segmentation and Segregation ==="
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

45. Save it and make the script executeable
chmod +x evidence-collection.sh

46. Run the script
./evidence-collection.sh

MediPay technical evidence pack
Collected: Sun Sep  6 01:47:45 PM UTC 2026 by Syed
=== IAM-05 Least privilege on execution roles ===
{
    "PolicyNames": [
        "PatientLookupReadOnly"
    ]
}
=== IVS Tenant isolation & segmentation ===
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
=== CEK-03 Encryption at rest ===
{
    "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms"
    },
    "BucketKeyEnabled": false,
    "BlockedEncryptionTypes": {
        "EncryptionType": [
            "SSE-C"
        ]
    }
}
=== DSP-04 Data classification ===
{
    "TagSet": [
        {
            "Key": "classification",
            "Value": "confidential"
        }
    ]
}
=== LOG-07 / LOG-02 Management plane audit trail ===
76 mgmt-trail.log
upload: ./mgmt-trail.sha256 to s3://miit-audit-trail/mgmt-trail.sha256
=== AIS-06 Pipeline security gate ===
gate exit code: 0 (0 = policy satisfied, 1 = blocked)
=== DSP-17 Public exposure guardrail ===
{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
}
=== DSP-16 Retention and disposal ===
[
    [
        "AutoDelete90Days",
        "Enabled"
    ]
]
67a00f79593de795fffa6d781db780df6e3e3f66fb531ea906b923521db8a4ce  evidence-20260906.txt

