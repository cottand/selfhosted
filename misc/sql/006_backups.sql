CREATE SCHEDULE backup_b2_all
    FOR BACKUP INTO 's3://dcotta-roachdb-bu-918dh91/scheduled?AWS_ACCESS_KEY_ID=_&AWS_SECRET_ACCESS_KEY=_&AWS_ENDPOINT=s3.us-east-005.backblazeb2.com'
    RECURRING '@daily'
    FULL BACKUP ALWAYS
    WITH SCHEDULE OPTIONS first_run = 'now';