public class Pulse_Project_TriggerHandler {
    public static boolean secondRun = false;
    
    public static void handleInsertTrigger(list<EDiscovery_Project__c> triggerNew){
        if(trigger.isBefore){
            getProjectCodeForProject(triggerNew);
        } else {
            // The EDiscovery_Project__c finds all EDiscovery_PricingItems__c that correspond to the Record Type of 
            // the project and creates EDiscovery_PricingItems__c for them with an association to the Project record 
            // from the trigger.
            createPricingLibraryRecords(triggerNew, null, false);// the oldMap and isUpdate booleans are not necessary in the insert version.
            system.debug('just before I call build the WR');
            createWRCaseInitiation(triggerNew, null, false);
        }
    }
    
    public static void handleUpdateTrigger(list<EDiscovery_Project__c> triggerNew, map<Id, EDiscovery_Project__c> oldMap, boolean isUpdate){
            checkProjectCodes(triggerNew);
            // If the Admin_Tag field was updated to be 'Update Pricing Libraries during this update, find all
            // Pricing Items not associated to the Project and create Libraries for them. 
            createPricingLibraryRecords(triggerNew, oldMap, isUpdate);
            createWRCaseInitiation(triggerNew, oldMap, isUpdate);      
    }
    
    // -- Before Insert -- //
    
    public static void getProjectCodeForProject(list<EDiscovery_Project__c> triggerNew){ // limit this trigger to run if there is only one item to process 
        integer padSize = 4;
        map<string, integer> highestNumericComponent = new map<string, integer>();
        if(triggerNew.size() == 1) {
            for(EDiscovery_Project__c prj : triggerNew) {            
                if(prj.Client_Code__c != null && prj.Oppty_SAP_Client_Name__c != null) {
                    if(prj.ESI_Project_Code__c == null) {
                        string codeNumeric = '0';
                        storeHighestByClientCode(prj.Client_Code__c, codeNumeric, highestNumericComponent);
                        for(EDiscovery_Project__c each : [select Id, ESI_Project_Code__c from EDiscovery_Project__c 
                                                            where ESI_Project_Code__c like : prj.Client_Code__c + '%'
                                                            and ESI_Project_Code__c != null order by ESI_Project_Code__c desc]){
                            string ProjectCodeEnd =  each.ESI_Project_Code__c.substring(prj.Client_Code__c.length()); // get the code minus the Client Code
                            if(!ProjectCodeEnd.substring(0,1).isNumeric()) continue; // if the first character isn't numeric this isn't the right client code to increment
                            codeNumeric = removeNonNumericEnd(ProjectCodeEnd);
                            storeHighestByClientCode(prj.Client_Code__c, codeNumeric, highestNumericComponent);
                        }
                        codeNumeric = string.valueOf(highestNumericComponent.get(prj.Client_Code__c) + 1);
                        string region = prj.Oppty_Region__c;
                        // Europe gets a 3 digit padded project code, all others get 4 digits
                        if(region != null) 
                        if(prj.Oppty_Region__c.contains('Europe')) PadSize = 3;
                        if(region == null || region == '')
                            region = ';';
                        // EMS Projects get a 5 digit padded project code
                        if(prj.Delivery_Location__c != null) {
                            if(prj.Delivery_Location__c.contains('EMS')) PadSize = 5;
                        } 
                        // if there are multiple regions then DO NOT CREATE the project code. 
                        if(region.countMatches(';') == 1) {
                            prj.ESI_Project_Code__c = prj.Client_Code__c + codeNumeric.leftPad(padSize, '0');   
                        }
                    }
                } else {
                    checkClientCodeValues(prj);
                }
            }        
        }
    }
    
    // populate the map that holds the highest found value for the numeric portion of the new Projects ESI Project code.
    private static void storeHighestByClientCode(string clientCode, string codeNumeric, map<string, integer> highestNumericComponent){
        integer currentNumeric = integer.valueOf(codeNumeric);
        if(highestNumericComponent.get(clientCode) == null){ // set the initial value to zero, this will be incremented and used if no matching Projects are found
            highestNumericComponent.put(clientCode, 0);
        }        
        if(highestNumericComponent.get(clientCode) < currentNumeric) { // check if stored number is lower than the current and replace if necessary
            highestNumericComponent.put(clientCode, currentNumeric);
        }   
    }
    
    private static void checkClientCodeValues(EDiscovery_Project__c prj){
        if((prj.Client_Code__c == null || prj.Oppty_SAP_Client_Name__c == null) && 
           prj.Delivery_Location__c != null && prj.Delivery_Location__c.startsWithIgnoreCase('Electronic')){
                prj.addError('Cannot create or edit the ESI project without a Client Code and SAP Client Name on the Opportunity!');
        }
        
    }
    
    private static string removeNonNumericEnd(string codeNumeric){
        string numeric = '';
        boolean numericTrimmed = false;
        while(!numericTrimmed){
            if(codeNumeric.length() >= 1){
                if(codeNumeric.length() > 1 && codeNumeric.substring(0,1).isNumeric()){
                    numeric = numeric + codeNumeric.substring(0,1);
                    integer endIndex = codeNumeric.length();
                    codeNumeric = codeNumeric.substring(1, endIndex);
                } else {
                    if(codeNumeric.isNumeric()){
                        numeric = numeric + codeNumeric;
                    }
                    numericTrimmed = true;
                }
            } else {
                numericTrimmed = true;
            }
        }
        return numeric;
    }
    
    // -- After Insert - After Update -- //
    
    public static void checkProjectCodes(list<EDiscovery_Project__c> triggerNew){
        for(EDiscovery_Project__c prj : triggerNew){
            checkClientCodeValues(prj);
        }
    }
    
    public static void createPricingLibraryRecords(list<EDiscovery_Project__c> triggerNew, map<id, EDiscovery_Project__c> oldMap, boolean isUpdate){
        map<string, list<EDiscovery_PricingItems__c>> pricingItemsByType = getAllPricingItemsByType();
        List<EDiscovery_PricingLibrary__c> projectPricingItems = new list<EDiscovery_PricingLibrary__c>();
        map<Id, set<string>> projectLibraries = new map<Id, set<string>>();
        if(isUpdate) getExistingProjectLibraries(triggerNew, projectLibraries);
        for(EDiscovery_Project__c project : triggerNew){
            if(project.isCloned__c && !isUpdate) continue; // Don't copy over Pricing Items is Project is a clone
            if(isUpdate && !libraryActionRequest(project, oldMap)){
                continue; // on an update only do this process if specifically requested.
            }
            list<EDiscovery_PricingItems__c> itemsNeeded = new list<EDiscovery_PricingItems__c>();
            if(project.Record_Type_Name__c == 'Data Center Project'){ // grab appropriate list of items based on Record Type
                itemsNeeded = pricingItemsByType.get('DataCenterItems');
            }else if(project.Record_Type_Name__c == 'Field Office Project'){
                itemsNeeded = pricingItemsByType.get('FieldOfficeItems');
            }
            if(isUpdate && projectLibraries.get(project.Id).size() > 0){ //remove Pricing Item if a Library record already exists for it.
                filteritemsNeeded(projectLibraries.get(project.Id), itemsNeeded);
            }
            createPricingLibrariesForProject(project, itemsNeeded, projectPricingItems);
        }
    
        if(ProjectPricingItems.size() > 0) insert projectPricingItems;
        
    }
    
    // Remove the Pricing Items from the list to be associated if its name is in the set retrieved from the existing Pricing Libraries.
    public static void filterItemsNeeded(set<string> pricingItemsAssociated, list<EDiscovery_PricingItems__c> itemsNeeded){
        for(integer x = itemsNeeded.size() - 1; x >= 0; x--){
            if(pricingItemsAssociated.contains(itemsNeeded[x].Name)) itemsNeeded.remove(x);
        }
    }
    
    // get a map of projectIds to a set of all Pricing Items already associated.
    public static void getExistingProjectLibraries(list<EDiscovery_Project__c> triggerNew, map<Id, set<string>> projectLibraries){
        set<string> projectIds = Pulse_Utils.getFieldValueSet(triggerNew, 'Id');
        list<EDiscovery_PricingLibrary__c> pricingLibraries = [select Id, Project__c, Pricing_Item_ID__c from EDiscovery_PricingLibrary__c where Project__c in : projectIds];
        for(EDiscovery_PricingLibrary__c each : pricingLibraries){
            if(projectLibraries.get(each.Project__c) == null) projectLibraries.put(each.Project__c, new set<string>());
            projectLibraries.get(each.Project__c).add(each.Pricing_Item_ID__c);
        }
    }
    
    // proceed with the update of libraries only if the Admin_Tag field was updated to that value as part of this trigger action.
    public static boolean libraryActionRequest(EDiscovery_Project__c project, map<id, EDiscovery_Project__c> oldProjects){
        return(project.Admin_Tag__c == 'Update_Pricing_Libraries' && 
               oldProjects.get(project.Id).Admin_Tag__c != 'Update_Pricing_Libraries');
    }
    
    // return map of Pricing Items to type either DataCenterItems or FieldOfficeItems
    public static map<string, list<EDiscovery_PricingItems__c>> getAllPricingItemsByType(){
        list<EDiscovery_PricingItems__c> PricingItems = [Select Id, Name, BillableItem__c, ProcessingPlatform__c, HostingPlatform__c, 
                                                        WRType__c, Monthly__c, TieredPricingCategory__c, PricingType__c, MinimumFee__c, 
                                                        Material_Code__c, Rate__c, Unit__c, Service_Category__c, Labor_Item__c, 
                                                        Available_for_Data_Center__c, Available_for_Field_office__c, Resource_Code__c, 
                                                        GL_Account__c, GL_Account_Name__c, Rack_Rate__c 
                                                        From EDiscovery_PricingItems__c];
        
        map<string, list<EDiscovery_PricingItems__c>> pricingItemsByType = new map<string, list<EDiscovery_PricingItems__c>>();
        for(EDiscovery_PricingItems__c PI : PricingItems){
            if(PI.Available_for_Data_Center__c == true){
                if(pricingItemsByType.get('DataCenterItems') == null) pricingItemsByType.put('DataCenterItems', new list<EDiscovery_PricingItems__c>());
                pricingItemsByType.get('DataCenterItems').add(PI);
            }
            if(PI.Available_for_Field_office__c == true){
                if(pricingItemsByType.get('FieldOfficeItems') == null) pricingItemsByType.put('FieldOfficeItems', new list<EDiscovery_PricingItems__c>());
                pricingItemsByType.get('FieldOfficeItems').add(PI);
            }
        }
        
        return pricingItemsByType;
    }
    
    public static void createPricingLibrariesForProject(EDiscovery_Project__c project, list<EDiscovery_PricingItems__c> itemsNeeded, 
                                                        list<EDiscovery_PricingLibrary__c> projectPricingItems){
        for(EDiscovery_PricingItems__c item : itemsNeeded){ // Create a Pricing Library entry for each Pricing Item
            projectPricingItems.add( new EDiscovery_PricingLibrary__c(
                Project__c = project.Id, 
                //Item__c = item.BillableItem__c,
                PricingItem__c = item.Id,
                //WRType__c = item.WRType__c,
                //Monthly__c = item.Monthly__c,
                //TieredPricingCategory__c = item.TieredPricingCategory__c,
                //PricingType__c = item.PricingType__c,
                //MinimumFee__c = item.MinimumFee__c,
                //Unit__c = item.Unit__c,
                //Rate__c = item.Rate__c,
                Service_Category__c = item.Service_Category__c,
                Labor_Item__c = item.Labor_Item__c,
                //Resource_Code__c = item.Resource_Code__c,
                //GL_Account__c = item.GL_Account__c,
                //GL_Account_Name__c = item.GL_Account_Name__c,
                //Rack_Rate__c = item.Rack_Rate__c,
                //Material_Code__c = item.Material_Code__c,
                Pricing_Item_ID__c = item.Name));           
        }
    }
    
    public static void createWRCaseInitiation(list<EDiscovery_Project__c> triggerNew, map<id, EDiscovery_Project__c> oldMap, boolean isUpdate){
        /* This routine loops thru the projects - ideally 1 project                              */
        /* The below checks to see if the WR type of Environment Setup - Case Initiation exists  */
        /* If WR of this type does not exist then create it                                      */
        /* Other Code crabs the RecordType id by looking for the name and not hard coding the ID */
        /* Also sets the owner to the queue by name as well                                      */
        
 
        for(EDiscovery_Project__c project : triggerNew){
              EDiscovery_Project__c OldProject = (OldMap != null? OldMap.get(project.Id) : null);
              system.debug('Inside the create wr case initiation');      
              list<EDiscovery_WorkRequest__c> WRCI = [select Id, name, project__c from EDiscovery_WorkRequest__c where recordtype.name = 'Environment Setup - Case Initiation' and project__c =: project.Id];
              list<RecordType> RTID = [Select id from recordtype where recordtype.name = 'Environment Setup - Case Initiation' LIMIT 1];
              list<Group> OwnerQ = [select Id from Group where Type = 'Queue' and Name = 'Technical Support' LIMIT 1]; 
              Integer SizeofList  = WRCI.size();
              system.debug('delivery location = ' + Project.Delivery_location__c);
              system.debug('project RT name = ' + project.Record_Type_Name__c);
              system.debug('Size of List = ' + SizeofList);
               if(SizeofList == 0 && Project.Delivery_Location__c == 'SEA DC' && project.Record_Type_Name__c == 'Data Center Project') {
                if(isupdate && Project.Delivery_Location__c != oldProject.Delivery_Location__c || !isupdate){
                  system.debug('inside if statement on size of list');
                  system.debug('project id = ' + project.id);
                  EDiscovery_WorkRequest__c WR = new EDiscovery_WorkRequest__c();
                  WR.Headline__c = 'Environment Set Up, Project Folders creation, and FTP Site Set Up.';
                  WR.PM_Instructions__c = 'Complete Environment Set Up, Create Project Folders, and Create FTP Site.';
                  WR.Project__c = project.id;
                  WR.RecordTypeId = RTID[0].id;
                  WR.Tech_Time_Description__c = 'N/A';
                  WR.Work_Request_Status__c = 'Submitted';
                  WR.OwnerId = OwnerQ[0].Id;
                  Insert WR;
                  system.debug('WR = ' + WR);
                }  
            }
           }  
        }
}
/*************************************************************************************************************************/
/*                                               Maintenance Notes                                                       */
/* User Story - 312303 - Added ability to auto create a WR of type Environment Setup - Case Initiatioin                  */ 
/* Modified by: Darren Davenport 12/20/2018                                                                              */
/*              Method createWRCaseInitiation was added for this user story                                              */
/*              The method checks to make sure a WR of this type does not exist before creating a new WR                 */
/*              The method will execute when a project is created or updated to meet the criteria                        */  
/*************************************************************************************************************************/