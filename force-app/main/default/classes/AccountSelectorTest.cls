@isTest
private class AccountSelectorTest {
    
    @TestSetup
    static void makeData(){
        
        UserRole userRole = [Select Id, DeveloperName From UserRole Where DeveloperName = 'CEO' Limit 1];
        User adminUser = [Select Id, UserRoleId From User Where Profile.Name='System Administrator' Limit 1];
        adminUser.UserRoleId = userRole.Id;
        adminUser.IsActive = true;
        update adminUser;       
        
        Id agencyRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Agency').getRecordTypeId();
        Id personRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Customer').getRecordTypeId();
        
        System.runAs(adminUser){
            Account agencyAccount = new Account(
                Name = 'Test Agency Account',
                RecordTypeId = agencyRecordTypeId
            );            
            insert agencyAccount;
            
            Account personAccount = new Account(
                FirstName = 'Test',
                LastName = 'Person Account',
                PersonEmail = 'personemail@example.com',
                Related_Agency__c = agencyAccount.Id,
                Language__c='es',
                RecordTypeId = personRecordTypeId
            );            
            insert personAccount;
            
        }
    }
    
    @isTest
    static void GetAccountById() {
        //Arrange
        AccountSelector selector = new AccountSelector();
        Account expectedAcc = [ SELECT Id FROM Account WHERE PersonEmail = 'personemail@example.com' ];
        //Act
        Account actualAcc = selector.GetAccountById(expectedAcc.Id);
        //Assert
        System.assertEquals(expectedAcc.Id, actualAcc.Id);
    }    
    
}