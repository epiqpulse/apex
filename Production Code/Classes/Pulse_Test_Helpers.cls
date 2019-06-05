/*
Name:           Pulse_Test_Helpers.cls
Description:    Holds common use Test Container for customizable record
creation, and various other methods
Method List:
Test Container{
Test_Container(integer numProjects, boolean insertProjects)
Test_Container(integer numProjects)
Test_Container()
createOpportunity()
createProjects(integer numProjects, boolean doInsert)
createProjectsWithRecordType(integer numProjects, string recordType, boolean doInsert)
createPricingItems()
createMedia(integer noOfMedia, boolean doInsert)
createUser(boolean doInsert)
createUser(boolean doInsert, string profile) 
createUsers(integer noOfUsers, boolean doInsert)
createUsers(integer noOfUsers, string profile, boolean doInsert)
createWorkRequestWithRecordType(integer noOfWR, string recordType, boolean doInsert)
createWorkRequests(boolean doInsert)
findPricingLibraries()
findWorkRequestTasks()
findBillableItems()
filterRecordTypesandReturnIds(map<Id, string> RecordTypeMap)
createQceEntries(integer noOfEntries, boolean doInsert)
createTimeEntries(integer noOfEntries, boolean doInsert)
createProjectTimeActivities(integer noOfActivities, boolean doInsert)
createApplicationDatabases(boolean doInsert)
createApplicationDatabaseAssignments(boolean doInsert)
createInternalTasks(Integer noOfTasks, boolean doInsert)
createInternalProjects(Integer noOfProjects, string recordType, boolean doInsert)
createInternalWorkRequests(Integer noOfWorkRequests, string recordType, boolean doInsert)
findInternalWRTasks()
}
createUser(boolean doInsert)
createUser(boolean doInsert, string profile)
CreateRecordTypeList()
CreateRecordTypeList2()
CreateRecordTypeListEMS()
CreateGeneralRecordType()
CreateProjectList(integer numProjects)
getRandomNumber(Integer size)
CreateMediaList(integer numMedia)
CreateCustodianAssignmentList(list<EDiscovery_Media__c> mediaList)
CreateWRTaskList(integer numTasks, EDiscovery_WorkRequest__c wr)
CreateTaskSettings(integer numSettings)


Date            Version         Author              Summary of Changes  
-----------------------------------------------------------------------------------------------
12/30/2018      1.0             Jerry Daru          Added method list comment and some Container methods 
for generating multiple Users.

1/10/2019       1.01            Jerry Daru          Added method to test container to create Internal Tasks
related to the Pulse Projects already in container.
-----------------------------------------------------------------------------------------------*/
@isTest
public class Pulse_Test_Helpers {
    
    // test container for uniform setup of unit tests. Default constructor only creates 
    // the Contact, Opportunity, and Pricing Items. Other Constructors will create and 
    // insert a single Project or a number of Projects potentially not inserted. 
    // Also contains methods to create associated records that might 
    // be necessary in various tests . 
    public class Test_Container {
        public Opportunity testOpportunity {get; set;}
        public Contact testContact {get; set;}
        public User testUser {get; set;}
        public list<User> testUsers {get; set;}
        public list<EDiscovery_Project__c> discoPros {get; set;}
        public list<EDiscovery_PricingItems__c> testPricingItems {get; set;}
        public list<EDiscovery_PricingLibrary__c> testPricingLibraries {get; set;}
        public list<EDiscovery_WorkRequest__c> testWorkRequests {get; set;}
        public list<EDiscovery_WR_Task__c> testWorkRequestTasks {get; set;}
        public list<Work_Request_Instruction__c> testWorkRequestInstructions {get; set;}
        public list<EDiscovery_BillableItems__c> testBillableItems {get; set;}
        public list<EDiscovery_Media__c> testMediaList {get; set;}
        public list<Time_Entry__c> testTimeEntries{get; set;}
        public list<Quality_Control_Entry__c> testQceEntries{get; set;}
        public list<Pulse_Project_Time_Activity__c> testProjectTimeActivities {get; set;}
        public list<EDiscovery_ApplicationDatabases__c> testApplicationDatabases {get; set;}
        public list<Application_Database_Assignments__c> testAppDBAssignments {get; set;}
        public list<EDiscovery_Internal_Task__c> testInternalTasks {get; set;}
        public list<Internal_Project__c> testInternalProjects {get; set;}
        public list<Internal_Work_Request__c> testInternalWorkRequests {get; set;}
        public list<Internal_WR_Task__c> testInternalWRTasks {get; set;}
        
        public string TestSAPContractId {get; set;}
        
        // variables passed in to determine the number of Projects necessary and 
        // whether or not to insert them.
        public Test_Container(integer numProjects, boolean insertProjects){
            createOpportunity();
            createPricingItems();
            createProjects(numProjects, insertProjects);
            // Pricing Libraries are created as part of the Project trigger
            // the method below just queries for all of the ones associated
            // to the new Projects and assigns them to the containers list.
            if(insertProjects) findPricingLibraries();
        }
        
        // variables passed in to determine the number of Projects to create and insert.
        public Test_Container(integer numProjects){
            createOpportunity();
            createPricingItems();
            createProjects(numProjects, true);
            // Pricing Libraries are created as part of the Project trigger
            // the method below just queries for all of the ones associated
            // to the new Projects and assigns them to the containers list.
            findPricingLibraries();
        }
        
        // default constructor will only create the pricing items, Pulse Projects and other 
        // records will need to be created using the class methods.
        public Test_Container(){
            createOpportunity();
            createPricingItems();
        }
        
        public void createOpportunity(){            
            testContact = new Contact(FirstName='Test Contact',lastname='Test Last Name');
            insert testContact;
            
            testOpportunity = new Opportunity(
                Name = 'test',
                Region__c = 'North America',
                StageName = '3 - Presentation/Proposal',
                Internal_Referral__c = 'Rep Generated',
                Internal_Referral_lookup__c = testContact.id,
                CloseDate = System.today().addDays(15),
                Epiq_Client_Code__c = 'ZZZ',
                SAP_Client_Name__c = 'test_SAP_Client');
            insert testOpportunity;
        }
        
        public void createProjects(integer numProjects, boolean doInsert){
            map<Id, string> RecordTypeMap = Pulse_Utils.getSObjectRecordTypeMap('EDiscovery_Project__c');
            list<Id> rTypeIds = filterRecordTypesandReturnIds(RecordTypeMap);
            discoPros = new list<EDiscovery_Project__c>();
            for(integer i = 0; i < numProjects; i++) {
                Id rType = rTypeIds[math.mod(i, 2)];
                string rTypeName = RecordTypeMap.get(rType);
                string sapContract = '111' + string.valueof(i);
                discoPros.add(new EDiscovery_Project__c(
                    ProjectNumber__c = 'P-' + string.valueOf(getRandomNumber(i * 5000)),
                    Opportunity__c = testOpportunity.id,
                    Delivery_Location__c = (rTypeName == 'Data Center Project' ? 'Electronic Discovery - US' : 'POR DC'),
                    ESI_Project_Code__c = 'TT0099' + string.valueof(i),
                    SAP_Contract_ID__c= sapContract,
                    RecordTypeId = rType,
                    Project_Start_Date__c = system.today(),
                    Primary_PM__c = userInfo.getUserId()));
                if(TestSAPContractId == null) TestSAPContractId = sapContract;
            }
            if(doInsert)insert discoPros;
        }
        
        public void createProjectsWithRecordType(integer numProjects, string recordType, boolean doInsert){
            map<Id, string> RecordTypeMap = Pulse_Utils.getSObjectRecordTypeMap('EDiscovery_Project__c');
            Id rType;
            for(Id key : RecordTypeMap.keySet()){
                if(RecordTypeMap.get(key) == recordType) rType = key;    
            }
            discoPros = new list<EDiscovery_Project__c>();
            for(integer i = 0; i < numProjects; i++) {
                string sapContract = '111' + string.valueof(i);
                discoPros.add(new EDiscovery_Project__c(
                    ProjectNumber__c = 'P-' + string.valueOf(getRandomNumber(i * 5000)),
                    Opportunity__c = testOpportunity.id,
                    Delivery_Location__c = (recordType == 'Field Office Project' ? 'SEA DC' : 'Electronic Discovery - US'),
                    ESI_Project_Code__c = 'TT0099' + string.valueof(i),
                    SAP_Contract_ID__c= sapContract,
                    RecordTypeId = rType,
                    Project_Start_Date__c = system.today(),
                    Primary_PM__c = userInfo.getUserId()));
                if(TestSAPContractId == null) TestSAPContractId = sapContract;
            }
            if(doInsert)insert discoPros;  
        }
        



        public void createPricingItems(){
            testPricingItems = new list<EDiscovery_PricingItems__c>();
            for(integer x = 1; x <= 30; x++){

                EDiscovery_PricingItems__c item = new EDiscovery_PricingItems__c();
                item.BillableItem__c = 'Item' + string.valueOf(x);
                item.Material_Code__c = 'ABC'  + string.valueOf(x);
                item.Unit__c = 'Page';
                item.Rate__c = 0.03;
                item.WR_Billable_Types__c = 'DMX - Prefiltering;DMX - Processing;ESI - General;Field Office Work Request;Field Office Work Request v2;Monthly Auto Stats Collection;Monthly User & Storage';
                
                if(x > 20){
                    item.Available_for_Data_Center__c = true;   
                }else if(x > 10){
                    item.Available_for_Data_Center__c = true;
                    item.Available_for_Field_office__c = true;
                }else if(x > 0){
                    item.Available_for_Field_office__c = true;
                }
                
                testPricingItems.add(item);
            }
            
            insert testPricingItems;
        }
        
        public void createMedia(integer noOfMedia, boolean doInsert){
            testMediaList = new list<EDiscovery_Media__c>();
            for(integer x = 0; x <= noOfMedia - 1; x++){
                testMediaList.add(new EDiscovery_Media__c(
                    Project__c = discoPros[0].Id,
                    Evidence_Location__c = 'Epiq - US/PHX',
                    Media_Possession_CoC__c = 'Storage Bin',
                    Bin_Number__c = 'A-1-1'));
            }
            if(doInsert) insert testMediaList;
        }
        
        public void createUser(boolean doInsert){
            createUser(doInsert, null);
        }
        
        public void createUser(boolean doInsert, string profile) {
            if(profile == null) profile = 'System Administrator'; 
            Profile userProfile = [select Id, Name from Profile where Name = : profile];
            testUser = new User(FirstName = 'Test',
                                LastName = 'Test Code',
                                Email = 'test@test.com',
                                Alias = 'Tcode',
                                Username = 'testmedia1234@test.com',
                                CommunityNickname = 'test12',
                                LocaleSidKey = 'en_US',
                                TimeZoneSidKey = 'GMT',
                                ProfileID = userProfile.Id,
                                LanguageLocaleKey = 'en_US',
                                EmailEncodingKey = 'UTF-8',
                                Department = 'Hosting',
                                Division = 'Hosting',
                                Manager_All__c = 'TestManager');
            if(doInsert) insert testUser;
        }
        
        public void createUsers(integer noOfUsers, boolean doInsert) {
            createUsers(noOfUsers, null, doInsert);
        }
        
        public void createUsers(integer noOfUsers, string profile, boolean doInsert) {
            testUsers = new list<User>();
            for(integer x = 0; x < noOfUsers; x++) {
                createUser(false, profile);
                testUser.Username = string.valueOf(x) + testUser.UserName;
                testUser.Alias = string.valueOf(x) + 'test';
                testUser.CommunityNickname = string.valueOf(x) + 'test';
                testUser.EmployeeNumber = string.valueOf(123000 + x);
                testUsers.add(testUser);
            }
            if(doInsert) insert testUsers;
        }
        
        public void createWorkRequestWithRecordType(integer noOfWR, string recordType, boolean doInsert){
            testWorkRequests = new list<EDiscovery_WorkRequest__c>();
            map<Id, string> projectRTs = Pulse_Utils.getSObjectRecordTypeMap('EDiscovery_Project__c');
            RecordType wrRecordType = [Select Id, SObjectType, Name, IsActive, DeveloperName 
                                       From RecordType Where SObjectType = 'EDiscovery_WorkRequest__c' 
                                       And IsActive = true AND Name = : recordType limit 1];
            system.debug(wrRecordType);
            for(EDiscovery_Project__c each : discoPros){
                // If the recordtype of the Project evaluates the same as the desired recordtype create Work Requests
                if(projectRTs.get(each.RecordTypeId).startsWith('Field') != recordType.startsWith('Field')) continue;
                for(integer x = 0; x < noOfWR; x++){
                    testWorkRequests.add(new EDiscovery_WorkRequest__c(
                        Project__c = each.Id,
                        RecordTypeId = wrRecordType.Id,
                        Headline__c = '*** HIPAA ***'
                    ));
                }
            }      
            if(doInsert) insert testWorkRequests;
        }
        
        public void createWorkRequests(boolean doInsert){
            testWorkRequests = new list<EDiscovery_WorkRequest__c>();
            map<Id, string> projectRTs = Pulse_Utils.getSObjectRecordTypeMap('EDiscovery_Project__c');
            list<RecordType> DataCenterRecordTypes = [ Select Id, SObjectType, Name, IsActive, DeveloperName 
                                                      From RecordType Where SObjectType = 'EDiscovery_WorkRequest__c' 
                                                      And IsActive = true 
                                                      AND Name IN ('ESI - General', 'DMX - Processing', 'DMX - Prefiltering', 
                                                                   'Monthly User & Storage', 'Monthly Auto Stats Collection')];
            list<RecordType> FieldOfficeRecordTypes = [ Select Id, SObjectType, Name, IsActive, DeveloperName 
                                                       From RecordType Where SObjectType = 'EDiscovery_WorkRequest__c' 
                                                       And IsActive = true 
                                                       AND Name IN ('Field Office - General', 'Field Office - Copying', 
                                                                    'Field Office - Printing', 'Field Office - Scanning', 'Field Office Work Request')];
            string headLine = '*** HIPAA ***';
            for(EDiscovery_Project__c each : discoPros){
                system.debug(projectRTs.get(each.RecordTypeId));
                list<RecordType> recordTypes = (projectRTs.get(each.RecordTypeId) == 'Field Office Project' ? FieldOfficeRecordTypes : DataCenterRecordTypes);
                for(RecordType eachRT : recordTypes){
                    testWorkRequests.add(new EDiscovery_WorkRequest__c(
                        Project__c = each.Id,
                        RecordTypeId = eachRT.Id,
                        Headline__c = headline
                    ));
                }
                headline = (headline == '*** HIPAA ***'? '*** ITAR ***' : '*** HIPAA ***');
            }           
            if(doInsert) insert testWorkRequests;
        }
        
        public void findPricingLibraries(){
            set<string> projIds = Pulse_Utils.getFieldValueSet(discoPros, 'Id');
            testPricingLibraries = [select Id, Project__c, Service_Category__c, Pricing_Item_ID__c,
                                    TieredPricingCategory__c, PricingType__c, Rate__c
                                    from EDiscovery_PricingLibrary__c where Project__c in : projIds];
            /*testPricingLibraries = [select Id, Project__c, Billable_Item__c, Unit__c, Service_Category__c, Pricing_Item_ID__c,
                                    TieredPricingCategory__c, PricingType__c, Rate__c
                                    from EDiscovery_PricingLibrary__c where Project__c in : projIds];*/
        }
        
        public void findWorkRequestTasks(){
            set<string> workRequestIds = Pulse_Utils.getFieldValueSet(testWorkRequests, 'Id');
            testWorkRequestTasks = [select Id, OwnerId, Task_Type__c, Task_Order__c, Work_Request__c, Status__c, Due_Date__c,
                                    RecordTypeId, Department__c, Sub_Department__c
                                    from EDiscovery_WR_Task__c where Work_Request__c in : workRequestIds];
        }
        
        public void findWorkRequestInstructions(){
            set<string> workRequestIds = Pulse_Utils.getFieldValueSet(testWorkRequests, 'Id');
            testWorkRequestInstructions = [select Id, Name, Work_Request__c from Work_Request_Instruction__c 
                                           where Work_Request__c in : workRequestIds]; 
        }
        
        public void findBillableItems(){
            set<string> pricingLibraryIds = Pulse_Utils.getFieldValueSet(testPricingLibraries, 'Id');
            testBillableItems = [select Id, PricingLibrary__c, Rate__c, Adjusted_Rate__c, Qty__c, Adjusted_Quantity__c, 
                                 PricingCategory__c, Tier1BilledAmt__c, Tier2BilledAmt__c, Tier3BilledAmt__c, WorkRequest__c,
                                 Tier1BilledQty__c, Tier2BilledQty__c, Tier3BilledQty__c, Tier1StorageRate__c, Tier2StorageRate__c, Tier3StorageRate__c, 
                                 isCloned__c, DataLoader__c, Project__c, Pricing_Item_Id__c, Material_Code__c, Sell_Amount__c
                                 from EDiscovery_BillableItems__c where PricingLibrary__c in : pricingLibraryIds];
        }
        
        public list<Id> filterRecordTypesandReturnIds(map<Id, string> RecordTypeMap){
            list<Id> rtIds = new list<Id>();
            for(Id each : RecordTypeMap.keySet()){
                string rTypeName = RecordTypeMap.get(each);
                if(rTypeName == 'Data Center Project' ||
                   rTypeName == 'Field Office Project'){
                       rtIds.add(each);
                   } else {
                       RecordTypeMap.remove(each);
                   }
            }
            return rtIds;
        }
        
        public void createQceEntries(integer noOfEntries, boolean doInsert){
            testQceEntries = new list<Quality_Control_Entry__c>();
            for(integer index = 0; index < noOfEntries; index ++){
                testQceEntries.add(new Quality_Control_Entry__c(
                    Work_Request__c = testworkrequests[0].id,
                    pass_or_fail__c = 'Pass',
                    Comments__c = 'test'
                ));
            }
            if(doInsert) insert testQceEntries;
        }    
        
        public void createTimeEntries(integer noOfEntries, boolean doInsert){
            testTimeEntries = new list<Time_Entry__c>();
            for(integer index = 0; index < noOfEntries; index ++){
                testTimeEntries.add(new Time_Entry__c(
                    Project__c = discoPros[0].Id,
                    Narrative__c = 'doing a test',
                    Project_Activity__c = 'test 0',
                    Date__c = Date.today(), 
                    Hours__c = 0.3
                ));
            }
            if(doInsert) insert testTimeEntries;
        }    
        
        public void createProjectTimeActivities(integer noOfActivities, boolean doInsert){
            testProjectTimeActivities = new list<Pulse_Project_Time_Activity__c>();
            
            for(integer x = 0; x < noOfActivities; x++){
                testProjectTimeActivities.add(new Pulse_Project_Time_Activity__c(Activity_Description__c = 'test ' + string.valueOf(x), Billable__c = 'No', Material_Code__c = 'stuff', 
                                                                                 SAP_Activity_ID__c = 'SAP-1234' + string.valueOf(x), SAP_Project_Definition__c = 'Test', Activity_Status__c = 'Active',
                                                                                 SAP_Contract_ID__c = TestSAPContractId));
            }
            
            if(doInsert) insert testProjectTimeActivities;
        }
        
        public void createApplicationDatabases(boolean doInsert){
            testApplicationDatabases = new list<EDiscovery_ApplicationDatabases__c>();
            map<id, string> recordTypeMap = Pulse_Utils.getSObjectRecordTypeMap('EDiscovery_ApplicationDatabases__c');
            for(id recordTypeId : recordTypeMap.keySet()){
                integer x = 1;
                system.debug(recordTypeMap.get(recordTypeId));
                if(recordTypeMap.get(recordTypeId) == 'DMX13' || recordTypeMap.get(recordTypeId) == 'DMX14_Processing'){
                    testApplicationDatabases.add(new EDiscovery_ApplicationDatabases__c(Project__c = discoPros[0].Id, Database_Name__c = 'testDB - ' + x, RecordTypeId = recordTypeId,
                                                                                        Database_Server__c = 'Client Site', Environment_Location__c = 'SEA DC'));
                    x++;
                }
            }   
            if(doInsert) insert testApplicationDatabases;
        }
        
        public void createApplicationDatabaseAssignments(boolean doInsert){
            testAppDBAssignments = new list<Application_Database_Assignments__c>();
            for(EDiscovery_ApplicationDatabases__c appDB : testApplicationDatabases){
                for(EDiscovery_WorkRequest__c wr : testWorkRequests){
                    testAppDBAssignments.add(new Application_Database_Assignments__c(Application_Database__c = appDB.Id, Work_Request__c = wr.Id));
                }
            }
            if(doInsert) insert testAppDBAssignments;
        }
        
        public void createInternalTasks(Integer noOfTasks, boolean doInsert) {
            testInternalTasks = new list<EDiscovery_Internal_Task__c>();
            datetime reqDateTime = datetime.now();
            for(EDiscovery_Project__c project : discoPros) {
                for(integer x = 0; x < noOfTasks; x++) {
                    testInternalTasks.add(
                        new EDiscovery_Internal_Task__c(
                            IT_Pulse_Project__c = project.Id, 
                            Requested_Time__c = reqDateTime.addDays(x + 1)
                        )
                    );
                }
            }
            if(doInsert) insert testInternalTasks;
        }
        
        public void createInternalProjects(Integer noOfProjects, string recordType, boolean doInsert){
            testInternalProjects = new list<Internal_Project__c>();
            map<id, string> recordTypeMap = Pulse_Utils.getSObjectRecordTypeMap('Internal_Project__c');
            id recordTypeId;
            for(id rtId : recordTypeMap.keySet()){
                if(recordTypeMap.get(rtId) == recordType) recordTypeId = rtId;
            }
            
            for(integer x = 0; x < noOfProjects; x++) {
                testInternalProjects.add(new Internal_Project__c(
                    RecordTypeId = recordTypeId,
                    Internal_Project_Name__c = 'testInternalProj - ' + string.valueOf(x),
                    KPIs__c = 'Count a lot of stuff and do things',                                                            

                    Target_Date__c = Date.Today().addDays(30)
                ));
            }
            
            if(doInsert) insert testInternalProjects;
        }
        
        public void createInternalWorkRequests(Integer noOfWorkRequests, string recordType, boolean doInsert){
            testInternalWorkRequests = new list<Internal_Work_Request__c>();
            map<id, string> recordTypeMap = Pulse_Utils.getSObjectRecordTypeMap('Internal_Work_Request__c');
            id recordTypeId;
            for(id rtId : recordTypeMap.keySet()){
                if(recordTypeMap.get(rtId) == recordType) recordTypeId = rtId;
            }
            
            for(Internal_Project__c internalProj : testInternalProjects) {
                for(integer x = 0; x < noOfWorkRequests; x++) {
                    testInternalWorkRequests.add(new Internal_Work_Request__c(
                        RecordTypeId = recordTypeId,
                        Acceptance_Criteria__c = 'the stuff we do looks pretty',
                        Internal_Project__c = internalProj.Id,
                        Due_Date__c = Date.Today().addDays(30),
                        Expected_Benefits__c = 'More efficient doing of things.',

                        Scope_In_Out__c = 'In Scope',
                        Point_of_Contact__c = UserInfo.getUserId(),

                        Region__c = 'EU',
                        User_story__c = 'test',
                        Sample_test_data__c = 'test',
                        Expected_output__c = 'test'
                    ));
                }
            }
            
            if(doInsert) insert testInternalWorkRequests;
        }
        
        public void findInternalWRTasks(){
            testInternalWRTasks = [select Internal_Work_Request__c, Internal_Work_Request__r.RecordType.Name, OwnerId, Status__c,
                                   Owners__c, RecordTypeId, Task_Completed__c, Task_Order__c, Task_Owners__c, Task_Started__c, Task_Type__c
                                   from Internal_WR_Task__c where Internal_Work_Request__c in : testInternalWorkRequests
                                   order by Task_Order__c];
        }
    }   
    
    // -------------------------
    
    public static User createUser(boolean doInsert){
        return createUser(doInsert, null);
    }
    
    public static User createUser(boolean doInsert, string profile) {
        if(profile == null) profile = 'System Administrator'; 
        Profile userProfile = [select Id, Name from Profile where Name = 'System Administrator'];
        User testUser = new User(LastName = 'Test Code',
                                 Email = 'test@test.com',
                                 Alias = 'Tcode',
                                 Username = 'testmedia1234@test.com',
                                 CommunityNickname = 'test12',
                                 LocaleSidKey = 'en_US',
                                 TimeZoneSidKey = 'GMT',
                                 ProfileID = userProfile.Id,
                                 LanguageLocaleKey = 'en_US',
                                 EmailEncodingKey = 'UTF-8',
                                 Department = 'Hosting',
                                 Division = 'Hosting',
                                 Manager_All__c = 'TestManager');
        if(doInsert) insert testUser;
        return testUser;
    }
    
    public static list<RecordType> CreateRecordTypeList() {
        list<RecordType> RecordTypes = [Select Id, SObjectType, Name, IsActive, DeveloperName 
                                        From RecordType Where SObjectType = 'EDiscovery_WorkRequest__c' And IsActive = true AND Name IN ('ESI - General', 'DMX - Processing', 'EH - Media', 'Environment Setup - DMX', 'Field Office Work Request', 'Hosting - Production', 'NUIX - Filter', 'TAR - Equivio Relevance')];
        return RecordTypes;     
    }
    
    public static list<RecordType> CreateRecordTypeList2() {
        list<RecordType> RecordTypes = [Select Id, SObjectType, Name, IsActive, DeveloperName 
                                        From RecordType Where SObjectType = 'EDiscovery_WorkRequest__c' And IsActive = true AND Name IN ('ESI - General', 'DMX - Processing')];
        return RecordTypes;     
    }
    
    public static list<RecordType> CreateRecordTypeListEMS() {
        list<RecordType> RecordTypes = [Select Id, SObjectType, Name, IsActive, DeveloperName 
                                        From RecordType Where SObjectType = 'EDiscovery_WorkRequest__c' And IsActive = true AND Name IN ('EMS Special / Non-Standard', 'EMS Relativity Processing')];
        return RecordTypes;     
    }
    
    public static list<RecordType> CreateGeneralRecordType() {
        list<RecordType> RecordTypes = [Select Id, SObjectType, Name, IsActive, DeveloperName 
                                        From RecordType Where SObjectType = 'EDiscovery_WorkRequest__c' And IsActive = true AND Name IN ('ESI - General')];
        return RecordTypes;     
    }
    public static list<RecordType> CreateAutoStatRecordType() {
        list<RecordType> RecordTypes = [Select Id, SObjectType, Name, IsActive, DeveloperName 
                                        From RecordType Where SObjectType = 'EDiscovery_WorkRequest__c' And IsActive = true AND Name IN ('Monthly Auto Stats Collection')];
        return RecordTypes;     
    }
    public static list<EDiscovery_Project__c> CreateProjectList(integer numProjects) {
        list<RecordType> RecordTypes = [Select Id, SObjectType, Name, IsActive, DeveloperName 
                                        From RecordType Where SObjectType = 'EDiscovery_Project__c' And IsActive = true AND Name IN ('Data Center Project', 'Field Office Project')];
        
        Contact c = new Contact(FirstName='Test Contact',lastname='Test Last NAme');
        insert c;
        
        Opportunity o = new opportunity();
        o.Name= 'test';
        o.StageName = '3 - Presentation/Proposal';
        o.Internal_Referral__c='Rep Generated';
        o.Internal_Referral_lookup__c=c.id;
        o.CloseDate = System.today().addDays(15);
        o.Epiq_Client_Code__c = 'ZZZ';
        o.SAP_Client_Name__c = 'test_SAP_Client';
        insert o;
        
        list<EDiscovery_Project__c> Projects = new list<EDiscovery_Project__c>();
        for(integer i = 0; i < numProjects; i++) {
            EDiscovery_Project__c prj = new EDiscovery_Project__c();
            prj.ProjectNumber__c = 'P-' + string.valueOf(getRandomNumber(i * 5000));
            prj.Opportunity__c = o.id;
            prj.Delivery_Location__c = 'Electronic Discovery - US';
            prj.ESI_Project_Code__c = 'TT0099' + string.valueof(i);
            prj.SAP_Contract_ID__c= '111' + string.valueof(i);
            prj.RecordTypeId = RecordTypes[0].Id;
            prj.Project_Start_Date__c = system.today();
            if(i == 1) prj.RecordTypeId = RecordTypes[1].Id;
            //if(math.mod(i, 2) == 0) prj.RecordTypeId = RecordTypes[0].Id;
            Projects.Add(prj);          
        }
        insert Projects;
        
        return (Projects);
    }
    
    public static Integer getRandomNumber(Integer size){
        Double d = math.random() * size;
        return d.intValue();
    }
    
    public static list<EDiscovery_Media__c> CreateMediaList(integer numMedia) {
        list<EDiscovery_Project__c> projects = CreateProjectList(numMedia);
        list<EDiscovery_Media__c> mediaList = new list<EDiscovery_Media__c>();
        
        for(integer i = 0; i < numMedia; i++) {
            EDiscovery_Media__c media = new EDiscovery_Media__c();
            media.Project__c = projects[i].Id;
            media.Evidence_Location__c = 'Epiq - US/PHX';
            media.Media_Possession_CoC__c = 'Remote';
            mediaList.add(media);
        }
        insert mediaList;
        
        return mediaList;
    }
    
    public static list<Custodian_Assignment__c> CreateCustodianAssignmentList(list<EDiscovery_Media__c> mediaList) {
        list<Custodian_Assignment__c> custAssignments = new list<Custodian_Assignment__c>();
        list<Custodian__c> custList = new list<Custodian__C>();         
        
        for(EDiscovery_Media__c media : mediaList) {
            Custodian__c cust = new Custodian__c();             
            cust.Pulse_Project__c = media.Project__c;
            cust.First_Name__c = 'First Name';
            cust.Last_Name__c = 'Last Name';
            custList.add(cust);             
        }
        insert custList;
        
        for(integer i = 0; i < mediaList.size(); i++) {
            Custodian_Assignment__c custAssign = new Custodian_Assignment__c();
            custAssign.Media__c = mediaList[i].Id;
            custAssign.Custodian__c = custList[i].Id;
            custAssignments.add(custAssign);
        }       
        insert custAssignments;
        
        return custAssignments;
    }
    
    public static list<EDiscovery_WR_Task__c> CreateWRTaskList(integer numTasks, EDiscovery_WorkRequest__c wr) {
        list<EDiscovery_WR_Task__c> WRtasks = new list<EDiscovery_WR_Task__c>();
        
        for(integer i = 0; i < numTasks; i++) {         
            EDiscovery_WR_Task__c task = new EDiscovery_WR_Task__c();      
            task.Due_Date__c = System.today().addDays(2);
            task.Task_Type__c = 'TestType ' + string.valueOf(i + 1);
            task.Work_Request__c = wr.id;
            task.Status__c = 'Not Started';
            WRtasks.add(task);      
        }
        insert WRtasks;
        
        return WRTasks;
    }
    
    public static list<WR_Task_Settings__c> CreateTaskSettings(integer numSettings) {
        // will create the same number of settings for record type ESI - General and DMX - Processing 
        list<WR_Task_Settings__c> WRtaskSettings = new list<WR_Task_Settings__c>();
        
        for(integer i = 0; i < numSettings; i++) {
            WRtaskSettings.add(new WR_Task_Settings__c(
                Name = 'T-' + string.valueOf(i + 1),
                Task_Type__c = 'Test ' + string.valueOf(i + 1),
                Task_Order__c = (i + 1) * 10,
                Status__c = 'Not Started',
                Record_Type__c = 'ESI - General',
                Department__c = 'Hosting'));
            
            WRtaskSettings.add(new WR_Task_Settings__c(
                Name = 'T-' + string.valueOf(i + numSettings + 1),
                Task_Type__c = 'Test ' + string.valueOf(i + numSettings + 1),
                Task_Order__c = (i + 1) * 10,
                Status__c = 'Not Started',
                Record_Type__c = 'DMX - Processing',
                Department__c = 'Processing'));
        }
        insert WRtaskSettings;
        
        return WRTaskSettings;
    }
}