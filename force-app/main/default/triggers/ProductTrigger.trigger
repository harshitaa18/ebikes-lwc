trigger ProductTrigger on Product__c (before insert, before update, after insert, after update, after delete, after undelete) {
    
    // Handle DML operations and trigger metrics collection
    if (Trigger.isBefore && Trigger.isInsert) {
        // Before insert logic
        System.debug('ProductTrigger: Before Insert - Processing ' + Trigger.new.size() + ' records');
        validateProducts(Trigger.new);
    }
    
    if (Trigger.isBefore && Trigger.isUpdate) {
        // Before update logic
        System.debug('ProductTrigger: Before Update - Processing ' + Trigger.new.size() + ' records');
        validateProducts(Trigger.new);
        trackProductChanges(Trigger.oldMap, Trigger.newMap);
    }
    
    if (Trigger.isAfter && Trigger.isInsert) {
        // After insert logic - collect metrics
        System.debug('ProductTrigger: After Insert - Collecting metrics for ' + Trigger.new.size() + ' records');
        collectInsertMetrics(Trigger.new);
        publishMetricEvents('PRODUCT_INSERT', Trigger.new);
    }
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        // After update logic - collect metrics
        System.debug('ProductTrigger: After Update - Collecting metrics for ' + Trigger.new.size() + ' records');
        collectUpdateMetrics(Trigger.oldMap, Trigger.newMap);
        publishMetricEvents('PRODUCT_UPDATE', Trigger.new);
    }
    
    if (Trigger.isAfter && Trigger.isDelete) {
        // After delete logic - collect metrics
        System.debug('ProductTrigger: After Delete - Collecting metrics for ' + Trigger.old.size() + ' records');
        collectDeleteMetrics(Trigger.old);
        publishMetricEvents('PRODUCT_DELETE', Trigger.old);
    }
    
    if (Trigger.isAfter && Trigger.isUndelete) {
        // After undelete logic - collect metrics
        System.debug('ProductTrigger: After Undelete - Collecting metrics for ' + Trigger.new.size() + ' records');
        collectUndeleteMetrics(Trigger.new);
        publishMetricEvents('PRODUCT_UNDELETE', Trigger.new);
    }
    
    // Aggregate metrics at the end of trigger execution
    if (Trigger.isAfter) {
        aggregateTriggerMetrics();
    }
}

// Validation method
private void validateProducts(List<Product__c> products) {
    for (Product__c product : products) {
        if (product.MSRP__c != null && product.MSRP__c < 0) {
            product.MSRP__c.addError('MSRP cannot be negative');
        }
        
        if (String.isBlank(product.Name)) {
            product.Name.addError('Product name is required');
        }
    }
}

// Track product changes for metrics
private void trackProductChanges(Map<Id, Product__c> oldMap, Map<Id, Product__c> newMap) {
    for (Id productId : newMap.keySet()) {
        Product__c oldProduct = oldMap.get(productId);
        Product__c newProduct = newMap.get(productId);
        
        // Track price changes
        if (oldProduct.MSRP__c != newProduct.MSRP__c) {
            System.debug('Price change detected for Product ' + productId + 
                        ': Old=' + oldProduct.MSRP__c + ', New=' + newProduct.MSRP__c);
        }
        
        // Track category changes
        if (oldProduct.Category__c != newProduct.Category__c) {
            System.debug('Category change detected for Product ' + productId + 
                        ': Old=' + oldProduct.Category__c + ', New=' + newProduct.Category__c);
        }
    }
}

// Collect metrics for insert operations
private void collectInsertMetrics(List<Product__c> newProducts) {
    Decimal totalValue = 0;
    Map<String, Integer> categoryCount = new Map<String, Integer>();
    Map<String, Integer> materialCount = new Map<String, Integer>();
    
    for (Product__c product : newProducts) {
        // Calculate total value
        if (product.MSRP__c != null) {
            totalValue += product.MSRP__c;
        }
        
        // Count by category
        if (product.Category__c != null) {
            String category = product.Category__c;
            if (!categoryCount.containsKey(category)) {
                categoryCount.put(category, 0);
            }
            categoryCount.put(category, categoryCount.get(category) + 1);
        }
        
        // Count by material
        if (product.Material__c != null) {
            String material = product.Material__c;
            if (!materialCount.containsKey(material)) {
                materialCount.put(material, 0);
            }
            materialCount.put(material, materialCount.get(material) + 1);
        }
    }
    
    // Log collected metrics
    System.debug('Insert Metrics - Total Value: ' + totalValue);
    System.debug('Insert Metrics - Category Count: ' + categoryCount);
    System.debug('Insert Metrics - Material Count: ' + materialCount);
}

// Collect metrics for update operations
private void collectUpdateMetrics(Map<Id, Product__c> oldMap, Map<Id, Product__c> newMap) {
    Integer priceChanges = 0;
    Integer categoryChanges = 0;
    Integer materialChanges = 0;
    Decimal totalPriceChange = 0;
    
    for (Id productId : newMap.keySet()) {
        Product__c oldProduct = oldMap.get(productId);
        Product__c newProduct = newMap.get(productId);
        
        // Track price changes
        if (oldProduct.MSRP__c != newProduct.MSRP__c) {
            priceChanges++;
            if (oldProduct.MSRP__c != null && newProduct.MSRP__c != null) {
                totalPriceChange += (newProduct.MSRP__c - oldProduct.MSRP__c);
            }
        }
        
        // Track category changes
        if (oldProduct.Category__c != newProduct.Category__c) {
            categoryChanges++;
        }
        
        // Track material changes
        if (oldProduct.Material__c != newProduct.Material__c) {
            materialChanges++;
        }
    }
    
    // Log collected metrics
    System.debug('Update Metrics - Price Changes: ' + priceChanges + ', Total Change: ' + totalPriceChange);
    System.debug('Update Metrics - Category Changes: ' + categoryChanges);
    System.debug('Update Metrics - Material Changes: ' + materialChanges);
}

// Collect metrics for delete operations
private void collectDeleteMetrics(List<Product__c> deletedProducts) {
    Decimal totalLostValue = 0;
    Map<String, Integer> categoryLoss = new Map<String, Integer>();
    
    for (Product__c product : deletedProducts) {
        // Calculate lost value
        if (product.MSRP__c != null) {
            totalLostValue += product.MSRP__c;
        }
        
        // Count lost by category
        if (product.Category__c != null) {
            String category = product.Category__c;
            if (!categoryLoss.containsKey(category)) {
                categoryLoss.put(category, 0);
            }
            categoryLoss.put(category, categoryLoss.get(category) + 1);
        }
    }
    
    // Log collected metrics
    System.debug('Delete Metrics - Total Lost Value: ' + totalLostValue);
    System.debug('Delete Metrics - Category Loss: ' + categoryLoss);
}

// Collect metrics for undelete operations
private void collectUndeleteMetrics(List<Product__c> undeletedProducts) {
    Decimal totalRecoveredValue = 0;
    
    for (Product__c product : undeletedProducts) {
        if (product.MSRP__c != null) {
            totalRecoveredValue += product.MSRP__c;
        }
    }
    
    System.debug('Undelete Metrics - Total Recovered Value: ' + totalRecoveredValue);
}

// Publish metric events for tracking
private void publishMetricEvents(String eventType, List<Product__c> products) {
    List<Manufacturing_Event__e> events = new List<Manufacturing_Event__e>();
    
    for (Product__c product : products) {
        Manufacturing_Event__e event = new Manufacturing_Event__e(
            Metric_Type__c = eventType,
            Record_Id__c = product.Id,
            Value__c = product.MSRP__c != null ? product.MSRP__c : 0
        );
        events.add(event);
    }
    
    if (!events.isEmpty()) {
        EventBus.publish(events);
        System.debug('Published ' + events.size() + ' metric events of type: ' + eventType);
    }
}

// Aggregate and summarize all trigger metrics
private void aggregateTriggerMetrics() {
    // This method demonstrates complex SOQL queries within trigger context
    // to show how metrics can be aggregated after DML operations
    
    try {
        // Get current product statistics after the DML operation
        AggregateResult[] stats = [
            SELECT 
                COUNT(Id) totalProducts,
                AVG(MSRP__c) avgPrice,
                MIN(MSRP__c) minPrice,
                MAX(MSRP__c) maxPrice,
                COUNT(DISTINCT Category__c) uniqueCategories
            FROM Product__c
            WITH USER_MODE
        ];
        
        // Get category distribution
        AggregateResult[] categoryStats = [
            SELECT 
                Category__c,
                COUNT(Id) productCount,
                AVG(MSRP__c) avgPrice
            FROM Product__c
            WHERE Category__c != null
            WITH USER_MODE
            GROUP BY Category__c
            ORDER BY COUNT(Id) DESC
        ];
        
        // Log aggregated metrics
        if (!stats.isEmpty()) {
            AggregateResult stat = stats[0];
            System.debug('Trigger Aggregate Metrics:');
            System.debug('- Total Products: ' + stat.get('totalProducts'));
            System.debug('- Average Price: ' + stat.get('avgPrice'));
            System.debug('- Min Price: ' + stat.get('minPrice'));
            System.debug('- Max Price: ' + stat.get('maxPrice'));
            System.debug('- Unique Categories: ' + stat.get('uniqueCategories'));
        }
        
        System.debug('Trigger Category Distribution:');
        for (AggregateResult catStat : categoryStats) {
            System.debug('- ' + catStat.get('Category__c') + ': ' + catStat.get('productCount') + 
                        ' products, avg price: ' + catStat.get('avgPrice'));
        }
        
    } catch (Exception e) {
        System.debug('Error in aggregateTriggerMetrics: ' + e.getMessage());
    }
}
