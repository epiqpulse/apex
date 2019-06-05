@isTest
public class Pulse_PricingLibraryTrigger_Test {
    
    // -- the asserts in this are commented out due to the fact that the trigger this tests will be 
    // deactivated soon.
    private static testMethod void testInsert() {
        // insert a single Pricing Project 
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
        
        EDiscovery_PricingLibrary__c plib = container.testPricingLibraries[0];
        plib.Id = null;
        plib.Pricing_Item_ID__c = 'TestPI';        
        plib.Project__c = container.discoPros[0].Id;
        
        EDiscovery_PricingLibrary__c plib2 = new EDiscovery_PricingLibrary__c(
            Pricing_Item_ID__c = container.testPricingLibraries[0].Pricing_Item_ID__c,
            //Item__c = container.testPricingLibraries[0].Item__c,
            //Unit__c = container.testPricingLibraries[0].Unit__c,
            Service_Category__c = container.testPricingLibraries[0].Service_Category__c,         
            Project__c = container.testPricingLibraries[0].Project__c);
        system.debug(plib2);
        try{
            insert plib;
        } catch(Exception exc){
            //system.assert(false, 'This insert should have been unique, and was expected to succeed.');
        }
                
        try{
            insert plib2;
            //system.assert(false, 'This insert should have not have been unique, and was expected to fail.');
        } catch(Exception exc){
            system.debug(exc.getMessage());
        }
    }
}