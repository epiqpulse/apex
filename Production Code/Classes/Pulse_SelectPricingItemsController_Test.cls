@isTest
public class Pulse_SelectPricingItemsController_Test {

        private static testMethod void testButton() {
            Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
                        
            test.StartTest();
                PageReference pageRef = Page.Pulse_AddNewPricingLibraryItem;
                pageRef.getParameters().put('projid', container.discoPros[0].Id);
                Test.setCurrentPage(pageRef);
                ApexPages.StandardSetController con = new ApexPages.StandardSetController(container.testPricingLibraries);
                Pulse_SelectPricingItemsController controller = new Pulse_SelectPricingItemsController(con);
                controller.Initialize();
                controller.pricingItems[0].selected = true;                     
                controller.addSelected();
                controller.addAll();
                controller.returnToProj();
            test.StopTest();
        }
}