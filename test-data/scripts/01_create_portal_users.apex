/**
 * Post-load setup for Customer Portal end-to-end demo data.
 *
 * Run order (after `sf data import tree`):
 *   1. This script (01_create_portal_users.apex) — creates community users
 *   2. 02_create_cases_and_surveys.apex          — creates support cases + CSAT surveys
 *   3. 03_create_documents.apex                  — uploads sample documents linked to policies
 *
 * Run from VS Code:  sf apex run --file scripts/01_create_portal_users.apex
 * Or paste into Developer Console → Execute Anonymous.
 *
 * SAFE TO RE-RUN: each step checks for existing records first.
 */

// =============================================================
// 01 — Create Customer Portal Users (1 per test customer Contact)
// =============================================================

// Find the Customer Portal User profile
Profile portalProfile = [
    SELECT Id, Name FROM Profile WHERE Name = 'Customer Portal User' LIMIT 1
];
System.debug('Portal profile id: ' + portalProfile.Id);

// Find permission sets to assign
Map<String, Id> permsetByName = new Map<String, Id>();
for (PermissionSet ps : [
    SELECT Id, Name FROM PermissionSet
    WHERE Name IN ('Customer_Portal_User', 'Customer_Portal_Admin')
]) {
    permsetByName.put(ps.Name, ps.Id);
}

// Pull seed contacts created by Account_insert.txt
List<Contact> seedContacts = [
    SELECT Id, FirstName, LastName, Email, AccountId, Account.Name
    FROM Contact
    WHERE LastName IN ('Test Customer', 'Sample Customer', 'Demo Customer')
];
System.debug('Seed contacts found: ' + seedContacts.size());

// Avoid duplicates — fetch any existing users for these contacts
Set<Id> existingUserContactIds = new Set<Id>();
for (User u : [
    SELECT Id, ContactId FROM User
    WHERE ContactId IN :seedContacts AND IsActive = true
]) {
    existingUserContactIds.add(u.ContactId);
}

List<User> usersToInsert = new List<User>();
for (Contact c : seedContacts) {
    if (existingUserContactIds.contains(c.Id)) {
        System.debug('User already exists for contact: ' + c.Email);
        continue;
    }
    String alias = (c.FirstName.substring(0,1) + c.LastName).toLowerCase();
    if (alias.length() > 8) alias = alias.substring(0, 8);
    User u = new User(
        FirstName       = c.FirstName,
        LastName        = c.LastName,
        Email           = c.Email,
        Username        = c.Email + '.portal.demo',  // unique
        Alias           = alias,
        ContactId       = c.Id,
        ProfileId       = portalProfile.Id,
        TimeZoneSidKey  = 'Australia/Sydney',
        LocaleSidKey    = 'en_AU',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        IsActive        = true,
        CommunityNickname = (c.FirstName + c.LastName + '_' + String.valueOf(Crypto.getRandomLong()).substring(0,4))
    );
    usersToInsert.add(u);
}

if (!usersToInsert.isEmpty()) {
    Database.SaveResult[] results = Database.insert(usersToInsert, false);
    for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
            System.debug('Created user: ' + usersToInsert[i].Username + ' (' + results[i].getId() + ')');
        } else {
            System.debug(LoggingLevel.ERROR, 'Failed to create user ' + usersToInsert[i].Username
                + ' → ' + results[i].getErrors()[0].getMessage());
        }
    }
}

// Assign permission sets
List<PermissionSetAssignment> psas = new List<PermissionSetAssignment>();
for (User u : [
    SELECT Id, Username FROM User
    WHERE ContactId IN :seedContacts AND IsActive = true
]) {
    if (permsetByName.containsKey('Customer_Portal_User')) {
        psas.add(new PermissionSetAssignment(
            AssigneeId = u.Id,
            PermissionSetId = permsetByName.get('Customer_Portal_User')
        ));
    }
}
if (!psas.isEmpty()) {
    Database.SaveResult[] psResults = Database.insert(psas, false);
    Integer ok = 0;
    for (Database.SaveResult r : psResults) if (r.isSuccess()) ok++;
    System.debug('Permission set assignments created: ' + ok + ' / ' + psas.size());
}

/*
System.debug('=== STEP 1 COMPLETE ===');
System.debug('Next: run 02_create_cases_and_surveys.apex');
System.debug('Note: Salesforce will email each new user a "set your password" link.');
System.debug('To bypass: System.resetPassword(userId, true) sends a fresh reset email; or use System.setPassword(userId, ''YourTestPwd!'') from Anonymous Apex.');
*/
