The steps:

1. docker start localstack
localstack

2. docker rm -f localstack 2>/dev/null
docker run -d --name localstack -p 4566:4566 \
-e LOCALSTACK_AUTH_TOKEN=$LOCALSTACK_AUTH_TOKEN \
-e ENFORCE_IAM=1 \
localstack/localstack-pro:latest
localstack
Unable to find image 'localstack/localstack-pro:latest' locally
latest: Pulling from localstack/localstack-pro
26c307b5e35a: Already exists 
f5ea60e5d57e: Pull complete 
c915bfca5450: Pull complete 
31a024bb115a: Pull complete 
2aa3d56d5806: Pull complete 
f8965a26001d: Pull complete 
60b3b1624b91: Pull complete 
4f4fb700ef54: Pull complete 
5800de510615: Pull complete 
2455a584ddea: Pull complete 
c5cfad14ddbe: Pull complete 
3bf928314df9: Pull complete 
05003aa1038d: Pull complete 
6b39abc220ff: Pull complete 
d16727f6beee: Pull complete 
2097843f931a: Pull complete 
78b99ce8fc39: Pull complete 
ed0f272a56e4: Pull complete 
8173d229e459: Pull complete 
56a84bab6449: Pull complete 
9664fa7ee9bd: Pull complete 
b135e31d490c: Pull complete 
a25c9a540f7b: Pull complete 
Digest: sha256:3fe5b51caec82b966a34485b5b43efd68075ff8161f9b0a34091fad9abb0ff82
Status: Downloaded newer image for localstack/localstack-pro:latest
d4712dd86ce38ce4148fc200451bfe34213a517bb5675af4c3e24255ff1c6e15

3. export EP='--endpoint-url=http://localhost:4566'
aws configure set aws_access_key_id test
aws configure set aws_secret_access_key test
aws configure set region us-east-1
aws $EP sts get-caller-identity

Task 1
4. export BUCKET=miit-patient-records-$RANDOM
echo $BUCKET                            
aws $EP s3api create-bucket --bucket $BUCKET
miit-patient-records-17876
{
    "Location": "/miit-patient-records-17876",
    "BucketArn": "arn:aws:s3:::miit-patient-records-17876"
}

5. echo 'Ward visiting hours 10am-8pm' > public-notice.txt
echo 'Staff duty schedule, week 12' > internal-roster.txt
echo 'Patient: Ahmad bin Ali, Diagnosis: confidential' > confidential-record.txt

6. aws $EP s3api put-object --bucket $BUCKET --key public/notice.txt --body public-notice.txt --tagging 'classification=public'
aws $EP s3api put-object --bucket $BUCKET --key internal/roster.txt --body internal-roster.txt --tagging 'classification=internal'
aws $EP s3api put-object --bucket $BUCKET --key confidential/record.txt --body confidential-record.txt --tagging 'classification=confidential'
{
    "ETag": "\"68e8daef2d7c6c68449a94dcea07d05e\"",
    "ChecksumCRC64NVME": "JmD2xi5CehE=",
    "ChecksumType": "FULL_OBJECT",
    "ServerSideEncryption": "AES256"
}

{
    "ETag": "\"0d9fd031956d640c0b4f1d95ddd64b1a\"",
    "ChecksumCRC64NVME": "NhcoKHoqy1k=",
    "ChecksumType": "FULL_OBJECT",
    "ServerSideEncryption": "AES256"
}

{
    "ETag": "\"9a86d9c8a68fe26ab3f63cd85c116a7f\"",
    "ChecksumCRC64NVME": "0JJivlclRBE=",
    "ChecksumType": "FULL_OBJECT",
    "ServerSideEncryption": "AES256"
}


7. aws $EP s3api list-objects-v2 --bucket $BUCKET --query 'Contents[].[Key,Size]' --output table
aws $EP s3api get-object-tagging --bucket $BUCKET --key confidential/record.txt

-----------------------------------
|          ListObjectsV2          |
+---------------------------+-----+
|  confidential/record.txt  |  48 |
|  internal/roster.txt      |  29 |
|  public/notice.txt        |  29 |
+---------------------------+-----+

{
    "TagSet": [
        {
            "Key": "classification",
            "Value": "confidential"
        }
    ]
}

Task 2
8. cat > public-policy.json <<JSON
{
"Version": "2012-10-17",
"Statement": [{
"Sid": "PublicReadEverything",
"Effect": "Allow",
"Principal": "*",
"Action": "s3:GetObject",
"Resource": "arn:aws:s3:::$BUCKET/*"
}]
}
JSON

9. cat public-policy.json
{
"Version": "2012-10-17",
"Statement": [{
"Sid": "PublicReadEverything",
"Effect": "Allow",
"Principal": "*",
"Action": "s3:GetObject",
"Resource": "arn:aws:s3:::miit-patient-records-17876/*"
}]
}

10. aws $EP s3api put-bucket-policy --bucket $BUCKET --policy file://public-policy.json
aws $EP s3api get-bucket-policy --bucket $BUCKET --query Policy --output text

{
"Version": "2012-10-17",
"Statement": [{
"Sid": "PublicReadEverything",
"Effect": "Allow",
"Principal": "*",
"Action": "s3:GetObject",
"Resource": "arn:aws:s3:::miit-patient-records-17876/*"
}]
}


11. curl -s -o leaked.txt -w 'HTTP %{http_code}\n' \
http://localhost:4566/$BUCKET/confidential/record.txt
HTTP 200

12. cat leaked.txt
Patient: Ahmad bin Ali, Diagnosis: confidential

Task 3
13. aws $EP s3api delete-bucket-policy --bucket $BUCKET

aws $EP s3api put-public-access-block --bucket $BUCKET \
--public-access-block-configuration \
BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

14. aws $EP s3api get-public-access-block --bucket $BUCKET
{
    "PublicAccessBlockConfiguration": {
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }
}

15. aws $EP s3api put-bucket-policy --bucket $BUCKET --policy file://public-policy.json

curl -s -o /dev/null -w 'anonymous read now: HTTP %{http_code}\n' \
http://localhost:4566/$BUCKET/confidential/record.txt
anonymous read now: HTTP 200

Verification Note: LocalStack stores the BPA configuration faithfully but does not always enforce it. Step 3 may succeed and the curl command may still return HTTP 200 instead of 403. If so, capture your get-public-access-block output as evidence.

16. cat > least-privilege-policy.json <<JSON
{
"Version": "2012-10-17",
"Statement":[{
"Sid": "AccountReadInternalOnly",
"Effect": "Allow",
"Principal": {"AWS": "arn:aws:iam::000000000000:root"},
"Action": "s3:GetObject",
"Resource": "arn:aws:s3:::$BUCKET/internal/*"
}]
}
JSON

17. aws $EP s3api put-bucket-policy --bucket $BUCKET --policy file://least-privilege-policy.json
aws $EP s3api get-bucket-policy --bucket $BUCKET --query Policy --output text

{
"Version": "2012-10-17",
"Statement":[{
"Sid": "AccountReadInternalOnly",
"Effect": "Allow",
"Principal": {"AWS": "arn:aws:iam::000000000000:root"},
"Action": "s3:GetObject",
"Resource": "arn:aws:s3:::miit-patient-records-17876/internal/*"
}]
}

Task 4
18. aws $EP iam create-user --user-name DataAnalyst

cat > analyst-iam.json <<'JSON'
{
"Version": "2012-10-17",
"Statement": [{
"Effect": "Allow",
"Action": ["s3:GetObject", "s3:ListBucket"],
"Resource": "*"
}]
}
JSON

aws $EP iam put-user-policy --user-name DataAnalyst \
--policy-name S3ReadAll --policy-document file://analyst-iam.json

{
    "User": {
        "Path": "/",
        "UserName": "DataAnalyst",
        "UserId": "AIDAQAAAAAAAKJ7EMGNPL",
        "Arn": "arn:aws:iam::000000000000:user/DataAnalyst",
        "CreateDate": "2026-09-09T18:51:00.709280+00:00"
    }
}

19. aws $EP iam create-access-key --user-name DataAnalyst \
--query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text

LKIAQAAAAAAAMMY72HBR    nyNthmaUji8HAhMqGAcH6aTY8bmqN/7y9RHc0oBj

20. ANALYST_KEY_ID='LKIAQAAAAAAAMMY72HBR'          
ANALYST_SECRET='nyNthmaUji8HAhMqGAcH6aTY8bmqN/7y9RHc0oBj'

aws configure --profile analyst set aws_access_key_id "$ANALYST_KEY_ID"
aws configure --profile analyst set aws_secret_access_key "$ANALYST_SECRET"
aws configure --profile analyst set region us-east-1

21. cat > deny-confidential.json <<JSON
{
"Version": "2012-10-17",
"Statement":[
{
"Sid": "AllowAnalystInternal",
"Effect": "Allow",
"Principal": {"AWS": "arn:aws:iam::000000000000:user/DataAnalyst"},
"Action": "s3:GetObject",
"Resource": "arn:aws:s3:::$BUCKET/internal/*"
},
{
"Sid": "DenyAnalystConfidential",
"Effect": "Deny",
"Principal": {"AWS": "arn:aws:iam::000000000000:user/DataAnalyst"},
"Action": "s3:*",
"Resource": "arn:aws:s3:::$BUCKET/confidential/*"
}
]
}
JSON

aws $EP s3api put-bucket-policy --bucket $BUCKET --policy file://deny-confidential.json

22. # Should SUCCEED - allowed by both policies
AWS_PROFILE=analyst aws $EP s3api get-object \
--bucket $BUCKET --key internal/roster.txt analyst-internal.txt && echo "internal: ALLOWED"

{
    "AcceptRanges": "bytes",
    "LastModified": "2026-09-09T18:02:08+00:00",
    "ContentLength": 29,
    "ETag": "\"0d9fd031956d640c0b4f1d95ddd64b1a\"",
    "ChecksumCRC64NVME": "NhcoKHoqy1k=",
    "ChecksumType": "FULL_OBJECT",
    "ContentType": "binary/octet-stream",
    "ServerSideEncryption": "AES256",
    "Metadata": {},
    "TagCount": 1
}

23. # Should FAIL - IAM allows, but the bucket policy explicitly denies
AWS_PROFILE=analyst aws $EP s3api get-object \
--bucket $BUCKET --key confidential/record.txt analyst-conf.txt || echo "confidential: DENIED"

{
    "AcceptRanges": "bytes",
    "LastModified": "2026-09-09T18:02:17+00:00",
    "ContentLength": 48,
    "ETag": "\"9a86d9c8a68fe26ab3f63cd85c116a7f\"",
    "ChecksumCRC64NVME": "0JJivlclRBE=",
    "ChecksumType": "FULL_OBJECT",
    "ContentType": "binary/octet-stream",
    "ServerSideEncryption": "AES256",
    "Metadata": {},
    "TagCount": 1
}

24. # Need to be failed (ENFORCE_IAM=1)
docker rm -f localstack 2>/dev/null
docker run -d --name localstack -p 4566:4566 \
-e LOCALSTACK_AUTH_TOKEN=$LOCALSTACK_AUTH_TOKEN \
-e ENFORCE_IAM=1 \
localstack/localstack-pro:latest
localstack
cce5eef72eeafc23b8eaad852a8dedd33e8b2cf35e65fb87a074fe3fe4e8220e

25. # Repaste this to re-establish the endpoint, create a new bucket, upload the internal and confidential files, recreate the IAM user, and re-apply the bucket policy.
export EP='--endpoint-url=http://localhost:4566'
export BUCKET=miit-patient-records-$RANDOM

# Recreate bucket and files
aws $EP s3api create-bucket --bucket $BUCKET
aws $EP s3api put-object --bucket $BUCKET --key internal/roster.txt --body internal-roster.txt --tagging 'classification=internal'
aws $EP s3api put-object --bucket $BUCKET --key confidential/record.txt --body confidential-record.txt --tagging 'classification=confidential'

# Recreate Analyst User and IAM Policy
aws $EP iam create-user --user-name DataAnalyst
aws $EP iam put-user-policy --user-name DataAnalyst --policy-name S3ReadAll --policy-document file://analyst-iam.json

# Re-apply the Disagreeing Bucket Policy
aws $EP s3api put-bucket-policy --bucket $BUCKET --policy file://deny-confidential.json

{
    "Location": "/miit-patient-records-9308",
    "BucketArn": "arn:aws:s3:::miit-patient-records-9308"
}

{
    "ETag": "\"0d9fd031956d640c0b4f1d95ddd64b1a\"",
    "ChecksumCRC64NVME": "NhcoKHoqy1k=",
    "ChecksumType": "FULL_OBJECT",
    "ServerSideEncryption": "AES256"
}

{
    "ETag": "\"9a86d9c8a68fe26ab3f63cd85c116a7f\"",
    "ChecksumCRC64NVME": "0JJivlclRBE=",
    "ChecksumType": "FULL_OBJECT",
    "ServerSideEncryption": "AES256"
}

26. aws $EP iam create-access-key --user-name DataAnalyst \
--query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text
LKIAQAAAAAAACT7MYWYN    S9RK4St+lHwHUcPHrUJ0SD0wBpuWdU1TihgE5VQe

27. aws configure --profile analyst set aws_access_key_id "LKIAQAAAAAAACT7MYWYN"                                                                  
aws configure --profile analyst set aws_secret_access_key "S9RK4St+lHwHUcPHrUJ0SD0wBpuWdU1TihgE5VQe"

28. aws configure --profile analyst list
NAME       : VALUE                    : TYPE             : LOCATION
profile    : analyst                  : manual           : --profile
access_key : ****************YWYN     : shared-credentials-file : 
secret_key : ****************5VQe     : shared-credentials-file : 
region     : us-east-1                : config-file      : ~/.aws/config

28. # Should SUCCEED
AWS_PROFILE=analyst aws $EP s3api get-object \
--bucket $BUCKET --key internal/roster.txt analyst-internal.txt && echo "internal: ALLOWED"

{
    "AcceptRanges": "bytes",
    "LastModified": "2026-09-09T19:15:43+00:00",
    "ContentLength": 29,
    "ETag": "\"0d9fd031956d640c0b4f1d95ddd64b1a\"",
    "ChecksumCRC64NVME": "NhcoKHoqy1k=",
    "ChecksumType": "FULL_OBJECT",
    "ContentType": "binary/octet-stream",
    "ServerSideEncryption": "AES256",
    "Metadata": {},
    "TagCount": 1
}

29. # Should failed
AWS_PROFILE=analyst aws $EP s3api get-object \
--bucket $BUCKET --key confidential/record.txt analyst-conf.txt || echo "confidential: DENIED"

{
    "AcceptRanges": "bytes",
    "LastModified": "2026-09-09T19:15:51+00:00",
    "ContentLength": 48,
    "ETag": "\"9a86d9c8a68fe26ab3f63cd85c116a7f\"",
    "ChecksumCRC64NVME": "0JJivlclRBE=",
    "ChecksumType": "FULL_OBJECT",
    "ContentType": "binary/octet-stream",
    "ServerSideEncryption": "AES256",
    "Metadata": {},
    "TagCount": 1
}


30. Since LocalStack is not enforcing the Deny policy, record both the analyst-iam.json and deny-confidential.json policy documents as your evidence instead of the AccessDenied screenshot.

Verification: Ensure you copy the JSON text exactly as you generated it in your terminal. You can also include a screenshot showing that LocalStack erroneously returned "ALLOWED" to prove you executed the command.

In your report, manually write out the AWS policy evaluation logic to explain what should have happened if the environment was functioning like real AWS.

Explain the evaluation order: default deny → any explicit Deny → any explicit Allow. Then, state exactly which statement in your JSON files should have decided the outcome for the two requests (the internal roster and the confidential record).

31. aws $EP s3api delete-bucket-policy --bucket $BUCKET

Task 5
32. export KEY_ID=$(aws $EP kms create-key \
--description 'IKB42603 Lab6 patient records bucket key' \
--query 'KeyMetadata.KeyId' --output text)

echo $KEY_ID
5c3a7ba4-caf8-420d-8357-bdfe164b2f6d


33. cat > encryption.json <<JSON
{
"Rules": [{
"ApplyServerSideEncryptionByDefault": {
"SSEAlgorithm": "aws:kms",
"KMSMasterKeyID": "$KEY_ID"
},
"BucketKeyEnabled": true
}]
}
JSON

34. aws $EP s3api put-bucket-encryption --bucket $BUCKET \
--server-side-encryption-configuration file://encryption.json

aws $EP s3api get-bucket-encryption --bucket $BUCKET

{
    "ServerSideEncryptionConfiguration": {
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "aws:kms",
                    "KMSMasterKeyID": "5c3a7ba4-caf8-420d-8357-bdfe164b2f6d"
                },
                "BucketKeyEnabled": true,
                "BlockedEncryptionTypes": {
                    "EncryptionType": [
                        "SSE-C"
                    ]
                }
            }
        ]
    }
}

35. aws $EP s3api put-object --bucket $BUCKET \
--key confidential/record-v2.txt --body confidential-record.txt
{
    "ETag": "\"9a86d9c8a68fe26ab3f63cd85c116a7f\"",
    "ChecksumCRC64NVME": "0JJivlclRBE=",
    "ChecksumType": "FULL_OBJECT",
    "ServerSideEncryption": "aws:kms",
    "SSEKMSKeyId": "arn:aws:kms:us-east-1:000000000000:key/5c3a7ba4-caf8-420d-8357-bdfe164b2f6d",
    "BucketKeyEnabled": true
}

36. aws $EP s3api head-object --bucket $BUCKET --key confidential/record-v2.txt \
--query '[ServerSideEncryption, SSEKMSKeyId, BucketKeyEnabled]' --output text

aws:kms arn:aws:kms:us-east-1:000000000000:key/5c3a7ba4-caf8-420d-8357-bdfe164b2f6d     True

37. # Because I use zsh, I need to do these instead:
URL=$(aws $EP s3 presign s3://$BUCKET/internal/roster.txt --expires-in 60)



38. echo $URL
http://localhost:4566/miit-patient-records-9308/internal/roster.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=test%2F20260909%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260909T200648Z&X-Amz-Expires=60&X-Amz-SignedHeaders=host&X-Amz-Signature=221ada20a110a899beab000ce4a109aa8176c31db01c6cbe5b08b1e0e957a8a8

39. curl -s -w '<-- HTTP %{http_code}\n' "$URL"
Staff duty schedule, week 12
<-- HTTP 200





