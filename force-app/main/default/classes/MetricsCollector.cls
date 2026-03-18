public with sharing class MetricsCollector {
    
    @AuraEnabled(Cacheable=true)
    public static Map<String, Object> getComprehensiveMetrics() {
        Map<String, Object> allMetrics = new Map<String, Object>();
        
        // Product metrics with multiple aggregations
        allMetrics.put('productMetrics', getProductMetrics());
        
        // Order metrics with aggregations
        allMetrics.put('orderMetrics', getOrderMetrics());
        
        // Cross-object analytics
        allMetrics.put('crossObjectMetrics', getCrossObjectMetrics());
        
        return allMetrics;
    }
    
    private static Map<String, Object> getProductMetrics() {
        Map<String, Object> metrics = new Map<String, Object>();
        
        // Complex SOQL aggregations for products
        AggregateResult[] priceDistribution = [
            SELECT 
                CASE 
                    WHEN MSRP__c < 500 THEN 'Budget'
                    WHEN MSRP__c < 1500 THEN 'Mid-Range'
                    WHEN MSRP__c < 3000 THEN 'Premium'
                    ELSE 'Luxury'
                END priceCategory,
                COUNT(Id) productCount,
                AVG(MSRP__c) avgPrice,
                MIN(MSRP__c) minPrice,
                MAX(MSRP__c) maxPrice
            FROM Product__c
            WHERE MSRP__c != null
            WITH USER_MODE
            GROUP BY 
                CASE 
                    WHEN MSRP__c < 500 THEN 'Budget'
                    WHEN MSRP__c < 1500 THEN 'Mid-Range'
                    WHEN MSRP__c < 3000 THEN 'Premium'
                    ELSE 'Luxury'
                END
            ORDER BY COUNT(Id) DESC
        ];
        
        // Category performance metrics
        AggregateResult[] categoryPerformance = [
            SELECT 
                Category__c,
                COUNT(Id) productCount,
                AVG(MSRP__c) avgPrice,
                COUNT(DISTINCT Material__c) materialVariety,
                COUNT(DISTINCT Level__c) levelVariety
            FROM Product__c
            WHERE Category__c != null
            WITH USER_MODE
            GROUP BY Category__c
            ORDER BY productCount DESC
        ];
        
        // Material-Level analysis
        AggregateResult[] materialLevelAnalysis = [
            SELECT 
                Material__c,
                Level__c,
                COUNT(Id) productCount,
                AVG(MSRP__c) avgPrice,
                MIN(MSRP__c) minPrice,
                MAX(MSRP__c) maxPrice
            FROM Product__c
            WHERE Material__c != null AND Level__c != null
            WITH USER_MODE
            GROUP BY Material__c, Level__c
            ORDER BY productCount DESC
        ];
        
        metrics.put('priceDistribution', priceDistribution);
        metrics.put('categoryPerformance', categoryPerformance);
        metrics.put('materialLevelAnalysis', materialLevelAnalysis);
        
        return metrics;
    }
    
    private static Map<String, Object> getOrderMetrics() {
        Map<String, Object> metrics = new Map<String, Object>();
        
        // Order value distribution
        AggregateResult[] orderValueDistribution = [
            SELECT 
                Order__c,
                COUNT(Id) itemCount,
                SUM(Qty_S__c + Qty_M__c + Qty_L__c) totalQuantity,
                SUM(Price__c * (Qty_S__c + Qty_M__c + Qty_L__c)) totalOrderValue,
                AVG(Price__c) avgItemPrice
            FROM Order_Item__c
            WITH USER_MODE
            GROUP BY Order__c
            ORDER BY totalOrderValue DESC
            LIMIT 10
        ];
        
        // Product popularity in orders
        AggregateResult[] productPopularity = [
            SELECT 
                Product__c,
                Product__r.Name productName,
                COUNT(Id) orderCount,
                SUM(Qty_S__c + Qty_M__c + Qty_L__c) totalQuantity,
                SUM(Price__c * (Qty_S__c + Qty_M__c + Qty_L__c)) totalRevenue
            FROM Order_Item__c
            WHERE Product__c != null
            WITH USER_MODE
            GROUP BY Product__c, Product__r.Name
            ORDER BY totalRevenue DESC
            LIMIT 20
        ];
        
        metrics.put('orderValueDistribution', orderValueDistribution);
        metrics.put('productPopularity', productPopularity);
        
        return metrics;
    }
    
    private static Map<String, Object> getCrossObjectMetrics() {
        Map<String, Object> metrics = new Map<String, Object>();
        
        // Products vs Orders correlation
        AggregateResult[] productOrderCorrelation = [
            SELECT 
                p.Category__c,
                p.Level__c,
                COUNT(DISTINCT p.Id) availableProducts,
                COUNT(DISTINCT oi.Product__c) orderedProducts,
                COUNT(oi.Id) totalOrderItems,
                AVG(oi.Price__c) avgOrderPrice
            FROM Product__c p
            LEFT JOIN Order_Item__c oi ON p.Id = oi.Product__c
            WITH USER_MODE
            GROUP BY p.Category__c, p.Level__c
            ORDER BY totalOrderItems DESC
        ];
        
        // Price vs Quantity analysis
        AggregateResult[] priceQuantityAnalysis = [
            SELECT 
                CASE 
                    WHEN Product__r.MSRP__c < 500 THEN 'Budget'
                    WHEN Product__r.MSRP__c < 1500 THEN 'Mid-Range'
                    WHEN Product__r.MSRP__c < 3000 THEN 'Premium'
                    ELSE 'Luxury'
                END priceCategory,
                COUNT(Id) orderCount,
                AVG(Qty_S__c + Qty_M__c + Qty_L__c) avgQuantity,
                SUM(Price__c * (Qty_S__c + Qty_M__c + Qty_L__c)) totalRevenue
            FROM Order_Item__c
            WHERE Product__r.MSRP__c != null
            WITH USER_MODE
            GROUP BY 
                CASE 
                    WHEN Product__r.MSRP__c < 500 THEN 'Budget'
                    WHEN Product__r.MSRP__c < 1500 THEN 'Mid-Range'
                    WHEN Product__r.MSRP__c < 3000 THEN 'Premium'
                    ELSE 'Luxury'
                END
            ORDER BY totalRevenue DESC
        ];
        
        metrics.put('productOrderCorrelation', productOrderCorrelation);
        metrics.put('priceQuantityAnalysis', priceQuantityAnalysis);
        
        return metrics;
    }
    
    @AuraEnabled
    public static void trackMetricEvent(String metricType, String recordId, Decimal value) {
        // DML operation to trigger metrics tracking
        Manufacturing_Event__e event = new Manufacturing_Event__e(
            Metric_Type__c = metricType,
            Record_Id__c = recordId,
            Value__c = value
        );
        
        EventBus.publish(event);
        
        // Log for tracking
        System.debug('Metric Event Published - Type: ' + metricType + ', Record: ' + recordId + ', Value: ' + value);
    }
}
