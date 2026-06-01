@isTest
public class AccountControllerTest {

    // -------------------------------------------------------------------
    // Test constants — change these in one place if labels or values shift.
    // -------------------------------------------------------------------
    private static final String USER_ROLE_DEV_NAME      = 'CEO';
    private static final String ADMIN_PROFILE_NAME      = 'System Administrator';
    private static final String PORTAL_PROFILE_NAME     = 'Customer Portal User';
    private static final String AGENCY_RT_NAME          = 'Agency';

    private static final String PERSON_EMAIL            = 'personemail@example.com';
    private static final String PORTAL_USER_EMAIL       = 'no.community@email.com';
    private static final String PORTAL_USER_USERNAME    = 'communitytest@uniquedomain.com';

    private static final String INITIAL_LANGUAGE        = 'es';
    private static final String UPDATED_LANGUAGE        = 'en_US';

    public static UserSelector selector = new UserSelector();

    @testSetup
    static void setuprecords() {

        // --- Ensure an admin with the required role is available -----------
        UserRole userRole = [
            SELECT Id, DeveloperName
            FROM UserRole
            WHERE DeveloperName = :USER_ROLE_DEV_NAME
            LIMIT 1
        ];
        User adminUser = [
            SELECT Id, UserRoleId
            FROM User
            WHERE Profile.Name = :ADMIN_PROFILE_NAME
            AND IsActive = true
            LIMIT 1
        ];
        adminUser.UserRoleId = userRole.Id;
        update adminUser;

        // --- Resolve record types dynamically ------------------------------
        Id agencyRecordTypeId = Schema.SObjectType.Account
            .getRecordTypeInfosByName()
            .get(AGENCY_RT_NAME)
            .getRecordTypeId();

        // Resolve the Person Account record type via SOQL so we don't depend
        // on the label being 'Customer' (it differs across orgs).
        Id personRecordTypeId;
        for (RecordType rt : [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
              AND IsPersonType = true
              AND IsActive = true
            LIMIT 1
        ]) {
            personRecordTypeId = rt.Id;
        }
        System.assertNotEquals(null, personRecordTypeId,
            'No active Person Account record type found in this org.');

        // --- Resolve portal profile dynamically ----------------------------
        Profile portalProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = :PORTAL_PROFILE_NAME
            LIMIT 1
        ];

        System.runAs(adminUser) {

            Account agencyAccount = new Account(
                Name         = 'Test Agency Account',
                RecordTypeId = agencyRecordTypeId
            );
            insert agencyAccount;

            Account personAccount = new Account(
                FirstName        = 'Test',
                LastName         = 'Person Account',
                PersonEmail      = PERSON_EMAIL,
                Related_Agency__c = agencyAccount.Id,
                Language__c      = INITIAL_LANGUAGE,
                RecordTypeId     = personRecordTypeId
            );
            insert personAccount;

            Contact customerContact = new Contact(
                LastName  = 'Community Contact Last',
                AccountId = agencyAccount.Id
            );
            insert customerContact;

            User customerUser = new User(
                ProfileId          = portalProfile.Id,
                EmailEncodingKey   = 'ISO-8859-1',
                LanguageLocaleKey  = 'en_US',
                TimeZoneSidKey     = 'America/New_York',
                LocaleSidKey       = 'en_US',
                FirstName          = 'Community First',
                LastName           = 'Community Last',
                Username           = PORTAL_USER_USERNAME,
                CommunityNickname  = 'testUserCommunity',
                Alias              = 'UC',
                Email              = PORTAL_USER_EMAIL,
                IsActive           = true,
                ContactId          = customerContact.Id
            );
            insert customerUser;
        }
    }

    @IsTest
    static void updateAccount() {
        // Arrange
        Account acc = [
            SELECT Id, Language__c
            FROM Account
            WHERE PersonEmail = :PERSON_EMAIL
            LIMIT 1
        ];
        System.assertEquals(INITIAL_LANGUAGE, acc.Language__c,
            'Precondition: account should start with the initial language.');

        User customerUser = selector.getUserByEmail(PORTAL_USER_EMAIL);
        System.assertNotEquals(null, customerUser,
            'Portal user should have been created in test setup.');

        // Act — run as the portal user, since that mirrors real usage
        Test.startTest();
        System.runAs(customerUser) {
            AccountController.updateLanguage(acc.Id, UPDATED_LANGUAGE);
        }
        Test.stopTest();

        // Assert — query OUTSIDE runAs, as the test-running user has full visibility
        Account updated = [
            SELECT Language__c
            FROM Account
            WHERE Id = :acc.Id
        ];
        System.assertEquals(UPDATED_LANGUAGE, updated.Language__c,
            'Language should be updated to ' + UPDATED_LANGUAGE);
    }
}