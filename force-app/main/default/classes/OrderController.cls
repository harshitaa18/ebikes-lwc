public with sharing class OrderController {
    @AuraEnabled(Cacheable=true)
    public static Order_Item__c[] getOrderItems(Id orderId) {
        return [
            SELECT
                Id,
                Qty_S__c,
                Qty_M__c,
                Qty_L__c,
                Price__c,
                Product__r.Name,
                Product__r.MSRP__c,
                Product__r.Picture_URL__c
            FROM Order_Item__c
            WHERE Order__c = :orderId
            WITH USER_MODE
        ];
    }

    @AuraEnabled
    public static Order_Item__c createOrderItem(Id orderId, Id productId, Decimal price, Integer qtyS, Integer qtyM, Integer qtyL) {
        // Perform DML operation to trigger metrics
        Order_Item__c newItem = new Order_Item__c(
            Order__c = orderId,
            Product__c = productId,
            Price__c = price,
            Qty_S__c = qtyS,
            Qty_M__c = qtyM,
            Qty_L__c = qtyL
        );
        
        insert newItem;
        
        // Log metrics for tracking
        System.debug('Order Item Created - ID: ' + newItem.Id + ', Order: ' + orderId + ', Product: ' + productId);
        
        return newItem;
    }

    @AuraEnabled
    public static Order_Item__c updateOrderItem(Id orderItemId, Decimal price, Integer qtyS, Integer qtyM, Integer qtyL) {
        // Perform DML operation to trigger metrics
        Order_Item__c item = [
            SELECT Id, Qty_S__c, Qty_M__c, Qty_L__c, Price__c, Order__c, Product__c
            FROM Order_Item__c
            WHERE Id = :orderItemId
            WITH USER_MODE
        ];
        
        item.Price__c = price;
        item.Qty_S__c = qtyS;
        item.Qty_M__c = qtyM;
        item.Qty_L__c = qtyL;
        
        update item;
        
        // Log metrics for tracking
        System.debug('Order Item Updated - ID: ' + orderItemId + ', New Price: ' + price);
        
        return item;
    }

    @AuraEnabled
    public static void deleteOrderItem(Id orderItemId) {
        // Perform DML operation to trigger metrics
        Order_Item__c item = [
            SELECT Id, Order__c, Product__c
            FROM Order_Item__c
            WHERE Id = :orderItemId
            WITH USER_MODE
        ];
        
        delete item;
        
        // Log metrics for tracking
        System.debug('Order Item Deleted - ID: ' + orderItemId);
    }

    @AuraEnabled(Cacheable=true)
    public static Map<String, Object> getOrderMetrics(Id orderId) {
        Map<String, Object> metrics = new Map<String, Object>();
        
        // Aggregate queries for order metrics
        AggregateResult[] orderStats = [
            SELECT 
                COUNT(Id) totalItems,
                SUM(Qty_S__c + Qty_M__c + Qty_L__c) totalQuantity,
                SUM(Price__c * (Qty_S__c + Qty_M__c + Qty_L__c)) totalValue,
                AVG(Price__c) avgPrice
            FROM Order_Item__c
            WHERE Order__c = :orderId
            WITH USER_MODE
        ];
        
        // Product category breakdown
        AggregateResult[] categoryBreakdown = [
            SELECT 
                Product__r.Category__c category,
                COUNT(Id) itemCount,
                SUM(Qty_S__c + Qty_M__c + Qty_L__c) totalQuantity
            FROM Order_Item__c
            WHERE Order__c = :orderId AND Product__r.Category__c != null
            WITH USER_MODE
            GROUP BY Product__r.Category__c
            ORDER BY totalQuantity DESC
        ];
        
        metrics.put('orderStats', orderStats);
        metrics.put('categoryBreakdown', categoryBreakdown);
        
        return metrics;
    }
}
