/**
 * 03_create_documents.apex
 * 
 * Uploads sample documents and links them to:
 *   - The Account of each portal user (policy‑style docs)
 *   - One of the existing Cases (claim‑style docs)
 * Safe to re‑run.
 */

// 1. Get portal users and their Accounts
List<User> portalUsers = [
    SELECT Id, ContactId, Contact.AccountId, Contact.Email
    FROM User
    WHERE Contact.LastName IN ('Test Customer', 'Sample Customer', 'Demo Customer')
      AND IsActive = true
];

if (portalUsers.isEmpty()) {
    System.debug('ERROR: No portal users found. Run 01_create_portal_users.apex first.');
    return;
}

// 2. Get an existing Case (any from step 2) to attach claim documents
List<Case> existingCases = [
    SELECT Id, Subject
    FROM Case
    WHERE ContactId IN (SELECT ContactId FROM User WHERE Id IN :portalUsers)
    LIMIT 1
];
Case targetCase;
if (!existingCases.isEmpty()) {
    targetCase = existingCases[0];
    System.debug('Using existing Case: ' + targetCase.Subject);
} else {
    // Fallback: create a simple Case for claim documents
    Contact anyContact = [SELECT Id FROM Contact WHERE Id IN (SELECT ContactId FROM User WHERE Id IN :portalUsers) LIMIT 1];
    targetCase = new Case(
        Subject = 'DEMO: New claim - hail damage',
        ContactId = anyContact.Id,
        Status = 'New',
        Origin = 'Customer Portal'
    );
    insert targetCase;
    System.debug('Created new claim Case: ' + targetCase.Id);
}

// 3. Skip if demo documents already exist
Integer existingDemoFiles = [
    SELECT COUNT() FROM ContentVersion WHERE Title LIKE 'DEMO:%' AND IsLatest = true
];
if (existingDemoFiles > 0) {
    System.debug('Demo documents already exist (' + existingDemoFiles + '); skipping.');
    return;
}

// 4. Build documents
List<ContentVersion> contentVersions = new List<ContentVersion>();

// Policy‑style documents (one per portal user’s Account)
Set<Id> accountIds = new Set<Id>();
for (User u : portalUsers) {
    if (u.Contact.AccountId != null) accountIds.add(u.Contact.AccountId);
}
List<Account> accounts = [SELECT Id, Name FROM Account WHERE Id IN :accountIds];

for (Account acc : accounts) {
    contentVersions.add(new ContentVersion(
        Title         = 'DEMO: Policy Schedule - ' + acc.Name,
        PathOnClient  = 'PolicySchedule_' + acc.Name + '.pdf',
        VersionData   = Blob.valueOf('Sample policy schedule for ' + acc.Name + ' (demo data)'),
        Origin        = 'H'
    ));
}

// Claim documents (attached to the Case)
contentVersions.add(new ContentVersion(
    Title         = 'DEMO: Roof damage photo',
    PathOnClient  = 'roof_damage.jpg',
    VersionData   = Blob.valueOf('Fake JPG content - placeholder for claim documentation'),
    Origin        = 'H'
));
contentVersions.add(new ContentVersion(
    Title         = 'DEMO: Repair quote',
    PathOnClient  = 'repair_quote.pdf',
    VersionData   = Blob.valueOf('Fake PDF content - repair quote $8,500'),
    Origin        = 'H'
));

// 5. Insert ContentVersions
insert contentVersions;
System.debug('Inserted ' + contentVersions.size() + ' ContentVersions.');

// 6. Get ContentDocumentIds
Map<Id, Id> docIdByVersionId = new Map<Id, Id>();
for (ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :contentVersions]) {
    docIdByVersionId.put(cv.Id, cv.ContentDocumentId);
}

// 7. Link documents
List<ContentDocumentLink> links = new List<ContentDocumentLink>();

// Link policy documents to Accounts
Integer idx = 0;
for (Account acc : accounts) {
    ContentVersion cv = contentVersions[idx++];
    links.add(new ContentDocumentLink(
        ContentDocumentId = docIdByVersionId.get(cv.Id),
        LinkedEntityId    = acc.Id,
        ShareType         = 'V',
        Visibility        = 'AllUsers'
    ));
}

// Link claim documents to the Case (last 2 ContentVersions)
for (Integer j = contentVersions.size() - 2; j < contentVersions.size(); j++) {
    ContentVersion cv = contentVersions[j];
    links.add(new ContentDocumentLink(
        ContentDocumentId = docIdByVersionId.get(cv.Id),
        LinkedEntityId    = targetCase.Id,
        ShareType         = 'V',
        Visibility        = 'AllUsers'
    ));
}

insert links;
System.debug('Created ' + links.size() + ' document links.');

System.debug('=== STEP 3 COMPLETE ===');
System.debug('Demo documents are ready. Portal users can now view them.');