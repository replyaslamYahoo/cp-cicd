/**
 * 02_create_cases_and_surveys.apex
 * 
 * Creates Cases + CSAT survey records (custom object Survey_CSAT__c).
 * Safe to re-run.
 */

// 1. Get portal users (seed customers from Account_insert.txt)
List<User> portalUsers = [
    SELECT Id, ContactId, Contact.FirstName, Contact.LastName, Contact.Email
    FROM User
    WHERE Contact.LastName IN ('Test Customer', 'Sample Customer', 'Demo Customer')
      AND IsActive = true
];

if (portalUsers.isEmpty()) {
    System.debug('ERROR: No portal users found. Run 01_create_portal_users.apex first.');
    return;
}

// 2. Case subjects & descriptions
Map<String, String> subjectByContact = new Map<String, String>{
    'Test Customer' => 'Unable to log in to portal',
    'Sample Customer' => 'Billing discrepancy on last invoice',
    'Demo Customer' => 'Product warranty extension request'
};
Map<String, String> descByContact = new Map<String, String>{
    'Test Customer' => 'After resetting password, I still get "Invalid credentials". Please help.',
    'Sample Customer' => 'Invoice #INV-1234 shows $250 but my contract says $200. Attached PDF.',
    'Demo Customer' => 'I bought a Deluxe Widget on 2025-01-15, want to extend warranty to 3 years.'
};

List<Case> casesToInsert = new List<Case>();
Set<String> existingCaseSubjects = new Set<String>();

Set<Id> contactIds = new Set<Id>();
for (User u : portalUsers) contactIds.add(u.ContactId);

// Avoid duplicate Cases
for (Case c : [SELECT Subject, ContactId FROM Case WHERE ContactId IN :contactIds]) {
    existingCaseSubjects.add(c.Subject + '|' + c.ContactId);
}

for (User u : portalUsers) {
    String subject = subjectByContact.get(u.Contact.LastName);
    if (subject == null) subject = 'General support request';
    
    String key = subject + '|' + u.ContactId;
    if (existingCaseSubjects.contains(key)) {
        System.debug('Skipping existing case: ' + subject);
        continue;
    }
    
    casesToInsert.add(new Case(
        Subject = subject,
        Description = descByContact.get(u.Contact.LastName),
        ContactId = u.ContactId,
        Status = 'New',
        Origin = 'Customer Portal'
    ));
}

if (!casesToInsert.isEmpty()) {
    insert casesToInsert;
    System.debug('Created ' + casesToInsert.size() + ' cases.');
} else {
    System.debug('No new cases to create.');
}

// Cases only appear in Messages Center when they have a visible TextPost feed item
List<Case> demoCases = [
    SELECT Id, Description, Subject
    FROM Case
    WHERE ContactId IN :contactIds
];
Set<Id> caseIdsWithFeed = new Set<Id>();
for (CaseFeed cf : [
    SELECT ParentId
    FROM CaseFeed
    WHERE ParentId IN :demoCases AND Type = 'TextPost' AND Visibility = 'AllUsers'
]) {
    caseIdsWithFeed.add(cf.ParentId);
}

List<FeedItem> feedsToInsert = new List<FeedItem>();
for (Case demoCase : demoCases) {
    if (caseIdsWithFeed.contains(demoCase.Id)) {
        continue;
    }
    feedsToInsert.add(new FeedItem(
        ParentId = demoCase.Id,
        Title = 'Support Center Requests',
        Body = demoCase.Description != null ? demoCase.Description : demoCase.Subject,
        Type = 'TextPost',
        IsRichText = true,
        Visibility = 'AllUsers',
        NetworkScope = 'AllNetworks'
    ));
}
if (!feedsToInsert.isEmpty()) {
    insert feedsToInsert;
    System.debug('Created ' + feedsToInsert.size() + ' case feed items for Messages Center.');
}

// 3. Create CSAT Survey records (custom object) for each new Case
Id csatRecordTypeId;
try {
    csatRecordTypeId = [SELECT Id FROM RecordType 
                        WHERE SObjectType = 'Survey_CSAT__c' 
                          AND DeveloperName = 'CSAT' LIMIT 1].Id;
} catch (QueryException e) {
    System.debug('Record type "CSAT" not found on Survey_CSAT__c. Using default.');
}

List<Survey_CSAT__c> surveysToInsert = new List<Survey_CSAT__c>();
Set<Id> casesWithSurvey = new Set<Id>();
for (Survey_CSAT__c existing : [SELECT Case__c FROM Survey_CSAT__c WHERE Case__c IN :casesToInsert]) {
    casesWithSurvey.add(existing.Case__c);
}

for (Case c : casesToInsert) {
    if (casesWithSurvey.contains(c.Id)) {
        System.debug('Survey already exists for Case ' + c.Id);
        continue;
    }
    Survey_CSAT__c survey = new Survey_CSAT__c(
        Case__c = c.Id
        // Name field omitted – read-only/auto-number
    );
    if (csatRecordTypeId != null) survey.RecordTypeId = csatRecordTypeId;
    surveysToInsert.add(survey);
}

if (!surveysToInsert.isEmpty()) {
    insert surveysToInsert;
    System.debug('Created ' + surveysToInsert.size() + ' CSAT survey records.');
} else {
    System.debug('No new surveys to create.');
}

System.debug('=== STEP 2 COMPLETE ===');
System.debug('Next: run 03_create_documents.apex');