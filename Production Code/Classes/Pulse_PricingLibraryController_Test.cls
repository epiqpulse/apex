@isTest
public class Pulse_PricingLibraryController_Test {

    private static testMethod void testUpdateButton() {
        // create two Pulse Projects(one of each Record Type) and insert them.
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(2, true);
        // create a list of Pricing Items that didn't exist when the Projects were inserted so
        // there are some that can be captured during the update
        list<EDiscovery_PricingItems__c> pricingItems = createNewPricingItems();   

        PageReference pageRef = Page.Pulse_UpdatePricingLibrary;
        pageRef.getParameters().put('projid', container.discoPros[0].id);
        pageRef.getParameters().put('projname', container.discoPros[0].Name);
        Test.setCurrentPage(pageRef);
        Pulse_PricingLibraryController con = new Pulse_PricingLibraryController();
        con.UpdateItems();
        
        PageReference pageRef2 = Page.Pulse_UpdatePricingLibrary;
        pageRef2.getParameters().put('projid', container.discoPros[0].id);
        pageRef2.getParameters().put('projname', container.discoPros[0].Name);
        Test.setCurrentPage(pageRef2);
        Pulse_PricingLibraryController con2 = new Pulse_PricingLibraryController();
        con2.UpdateItems();
        
        con2.Cancel();
    }
    
    private static list<EDiscovery_PricingItems__c> createNewPricingItems(){
        list<EDiscovery_PricingItems__c> pricingItems = new list<EDiscovery_PricingItems__c>();        
        for(integer x = 0; x < 5 ; x++) {            
            pricingItems.add(new EDiscovery_PricingItems__c(
                                BillableItem__c = 'NewDCItem' + string.valueOf(x),
                                Material_Code__c = 'DCABC2'  + string.valueOf(x),
                                Unit__c = 'Page',
                                Service_Category__c = 'Test',
                                Available_for_Data_Center__c = true));
            
            pricingItems.add(new EDiscovery_PricingItems__c(
                                BillableItem__c = 'NewFOItem' + string.valueOf(x),
                                Material_Code__c = 'FOABC2'  + string.valueOf(x),
                                Unit__c = 'Page',
                                Service_Category__c = 'Test',
                                Available_for_Field_office__c = true));
        }
        insert pricingItems;
    	return pricingItems;
    }
}