@isTest
public class Pulse_BillableItemTrigger_Test {
    
    // verify that the quantity field is populated correctly if Adjusted quantity is set to 0
    static testMethod void testAdjustedQuantity(){
        integer quantityValue = 4;
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
        container.createWorkRequests(true);
        container.findBillableItems();
        EDiscovery_BillableItems__c item = container.testBillableItems[0];
        item.Qty__c = quantityValue;
        update item;
        item = [select Id, Calculated_Quantity__c from EDiscovery_BillableItems__c where Id = : item.Id][0];
        // because Adjusted_Quantity was null so Calculated Quantity is = to Quantity field.
        system.assertEquals(quantityValue, item.Calculated_Quantity__c);
        item.Adjusted_Quantity__c = quantityValue;
        item.Adjusted_Quantity_Reason__c = 'Other';
        item.Adjusted_Quantity_Reason_Other__c = 'just because';
        item.Qty__c = quantityValue + 1;
        update item;
        item = [select Id, Calculated_Quantity__c from EDiscovery_BillableItems__c where Id = : item.Id][0];
        // because Adjusted_Quantity was not zero Calculated quantity should evaluate to it.
        system.assertEquals(quantityValue, item.Calculated_Quantity__c);
        item.Adjusted_Quantity__c = 0;
        item.Adjusted_Quantity_Reason__c = 'Other';
        item.Adjusted_Quantity_Reason_Other__c = 'just because';
        item.Qty__c = quantityValue;
        update item;
        item = [select Id, Calculated_Quantity__c from EDiscovery_BillableItems__c where Id = : item.Id][0];
        // because Adjusted_Quantity was set to zero the calculated quantity should also be zero.
        system.assertEquals(0, item.Calculated_Quantity__c);        
    }
    
    // Sell amount calculation for non Tiered and non Volume Billable Item
    // is simply a Quantity field * a Rate field.
   /*  static testMethod void testSellAmountCalculationStandard(){
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
        container.createWorkRequests(true);
        container.findBillableItems();
        EDiscovery_BillableItems__c item = container.testBillableItems[0];
        item.id = null;
        item.Quantity_PM__c = 2;
        insert item;
        item = [select Rate__c, Adjusted_Rate__c, Sell_Amount__c, Qty__c, Quantity_PM__c, Adjusted_Quantity__c from EDiscovery_BillableItems__c where Id = : item.Id][0];
        system.debug(item); */
        // The Pricing Library has a value for Rate, so assert that
        // an actual rate has been populated on the Billable Item
        //system.assert(item.Rate__c != null && item.Rate__c != 0.0);
        // sell amount should be 0.0 due to the Billable Item having
        // no value for Qty__c or Adjusted_Quantity__c
       /* system.assertEquals(0.0, item.Sell_Amount__c); */
        // update the quantity field on Billable Item and assert that 
        // a Sell Amount is calculated using it
      /* item.Qty__c = 1.0;
        item.Quantity_PM__c = null;
        update item;
        item = [select Rate__c, Adjusted_Rate__c, Sell_Amount__c, Qty__c, Quantity_PM__c, Adjusted_Quantity__c from EDiscovery_BillableItems__c where Id = : item.Id][0];
        system.debug(item);
        system.assertEquals(item.Rate__c * item.Qty__c, item.Sell_Amount__c); */
        // reset the trigger stopper after each assertion stage to ensure it isn't inaccurate.
       /* Pulse_BillableItem_TriggerHandler.secondRun = false; */
        // update the Adjusted_Quantity__c field on Billable Item and assert that 
        // a Sell Amount is calculated using it
      /*  item.Adjusted_Quantity__c = 3.0;
        item.Adjusted_Quantity_Reason__c = 'Other';
        item.Adjusted_Quantity_Reason_Other__c = 'just because';
        update item;
        item = [select Rate__c, Adjusted_Rate__c, Sell_Amount__c, Qty__c, Quantity_PM__c, Adjusted_Quantity__c from EDiscovery_BillableItems__c where Id = : item.Id][0];
        system.debug(item);
        system.assertEquals(item.Rate__c * item.Adjusted_Quantity__c, item.Sell_Amount__c); */
        // reset the trigger stopper after each assertion stage to ensure it isn't inaccurate.
      /*  Pulse_BillableItem_TriggerHandler.secondRun = false; */
        // update the Adjusted_Rate__c field on Billable Item and assert that 
        // a Sell Amount is calculated using it
      /*  item.Adjusted_Rate__c = 3.0;
        item.Adjusted_Rate_Reason__c = 'Other';
        item.Adjusted_Rate_Reason_Other__c = 'just because';
        update item;
        item = [select Rate__c, Adjusted_Rate__c, Sell_Amount__c, Qty__c, Quantity_PM__c, Adjusted_Quantity__c from EDiscovery_BillableItems__c where Id = : item.Id][0];
        system.debug(item);
        system.assertEquals(item.Adjusted_Rate__c * item.Adjusted_Quantity__c, item.Sell_Amount__c);
    } */
    
    // Test the Sell_Amount calculation for a Tiered Billable Item
  /*  static testMethod void testSellAmountCalculationTiered(){
        decimal quantityOne = 2;
        decimal rateOne = 0.3;
        decimal quantityTwo = 4;
        decimal rateTwo = 0.1;
        decimal quantityThree = 5;
        decimal rateThree = 0.5; */
        // values above will be inserted into fields on Project and later used to calculate Sell Amount
   /*     decimal finalValue = (quantityOne * rateOne) + (quantityTwo * rateTwo) + (quantityThree * rateThree);
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, false);
        map<string, string> updateMap = new map<string, string>{
                                            'TieredPricingCategory__c' => 'Storage',
                                            'PricingType__c' => 'Tiered'
                                        };
        Pulse_Utils.setFieldsToValues(container.testPricingItems, updateMap);
        update container.testPricingItems; */
        // adjust the following fields on the Project record before inserting. They are used in formula fields to determine
        // the value of the individual fields Sell_Amount__c is based upon on the Billable Item
      /*  container.discoPros[0].Tier_1_Storage_GB_Quantity__c = quantityOne;
        container.discoPros[0].Tier_1_Storage_Rate__c = rateOne; // price calculated for this tier will be .6
        container.discoPros[0].Tier_2_Storage_GB_Quantity__c = quantityTwo;
        container.discoPros[0].Tier_2_Storage_Rate__c = rateTwo; // price calculated for this tier will be .4
        container.discoPros[0].Tier_3_Storage_GB_Quantity__c = quantityThree;
        container.discoPros[0].Tier_3_Storage_Rate__c = rateThree; // price calculated for this tier will be 2.5
        insert container.discoPros;
        container.findPricingLibraries();
        container.createWorkRequests(true);
        container.findBillableItems();
        test.startTest();
        EDiscovery_BillableItems__c item = container.testBillableItems[0];
        item.id = null;
        item.Quantity_PM__c = 2;
        insert item;
        item = [select Rate__c, Adjusted_Rate__c, Sell_Amount__c, Qty__c, Quantity_PM__c, Adjusted_Quantity__c from EDiscovery_BillableItems__c where Id = : item.Id][0];
        system.debug(item); */
        // The Pricing Library has a value for Rate, so assert that
        // an actual rate has been populated on the Billable Item
        //system.assert(item.Rate__c != null && item.Rate__c != 0.0);
        // sell amount should be null due to the Billable Item having
        // having a Tiered pricing type and missing other necessary field values
        //system.assertEquals(0.0, item.Sell_Amount__c);
        // Updating Adjusted Quantity and Adjusted Rate 
        // These fields are checked, but not used in the actual calculation of
        // Sell Amount when the Billable Item is Tiered or Volumetric.
        // Sell Amount should equal the sum of each tiered Amount (Quantity * Rate)
        // expected total => 3.5
    /*    item.Adjusted_Quantity__c = 3.0;
        item.Adjusted_Quantity_Reason__c = 'Other';
        item.Adjusted_Quantity_Reason_Other__c = 'just because';
        item.Adjusted_Rate__c = 3.0;
        item.Adjusted_Rate_Reason__c = 'Other';
        item.Adjusted_Rate_Reason_Other__c = 'just because';
        item.Tier1BilledQty__c = quantityOne;
        item.Tier2BilledQty__c = quantityTwo;
        item.Tier3BilledQty__c = quantityThree;
        update item;
        test.stopTest();
        item = [select Id, Sell_Amount__c from EDiscovery_BillableItems__c where Id = : item.Id][0];
        system.assertEquals(finalValue, item.Sell_Amount__c);
    } */
}