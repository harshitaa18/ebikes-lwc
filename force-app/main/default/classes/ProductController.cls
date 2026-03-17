public with sharing class ProductController {
    static Integer PAGE_SIZE = 9;

    public class Filters {
        @AuraEnabled
        public String searchKey { get; set; }
        @AuraEnabled
        public Decimal maxPrice { get; set; }
        @AuraEnabled
        public String[] categories { get; set; }
        @AuraEnabled
        public String[] materials { get; set; }
        @AuraEnabled
        public String[] levels { get; set; }
    }

    @AuraEnabled(Cacheable=true scope='global')
    public static PagedResult getProducts(Filters filters, Integer pageNumber) {
        String key, whereClause = '';
        Decimal maxPrice;
        String[] categories, materials, levels, criteria = new List<String>{};
        if (filters != null) {
            maxPrice = filters.maxPrice;
            materials = filters.materials;
            levels = filters.levels;
            if (!String.isEmpty(filters.searchKey)) {
                key = '%' + filters.searchKey + '%';
                criteria.add('Name LIKE :key');
            }
            if (filters.maxPrice >= 0) {
                maxPrice = filters.maxPrice;
                criteria.add('MSRP__c <= :maxPrice');
            }
            if (filters.categories != null) {
                categories = filters.categories;
                criteria.add('Category__c IN :categories');
            }
            if (filters.levels != null) {
                levels = filters.levels;
                criteria.add('Level__c IN :levels');
            }
            if (filters.materials != null) {
                materials = filters.materials;
                criteria.add('Material__c IN :materials');
            }
            if (criteria.size() > 0) {
                whereClause = 'WHERE ' + String.join(criteria, ' AND ');
            }
        }
        Integer pageSize = ProductController.PAGE_SIZE;
        Integer offset = (pageNumber - 1) * pageSize;
        PagedResult result = new PagedResult();
        result.pageSize = pageSize;
        result.pageNumber = pageNumber;
        result.totalItemCount = Database.countQuery(
            'SELECT count() FROM Product__c ' + whereClause
        );
        result.records = Database.query(
            'SELECT Id, Name, MSRP__c, Description__c, Category__c, Level__c, Picture_URL__c, Material__c FROM Product__c ' +
                whereClause +
                ' WITH USER_MODE' +
                ' ORDER BY Name LIMIT :pageSize OFFSET :offset'
        );
        return result;
    }

    @AuraEnabled(Cacheable=true scope='global')
    public static Product__c[] getSimilarProducts(Id productId, Id familyId) {
        return [
            SELECT
                Id,
                Name,
                MSRP__c,
                Description__c,
                Category__c,
                Level__c,
                Picture_URL__c,
                Material__c
            FROM Product__c
            WHERE Product_Family__c = :familyId AND Id != :productId
            WITH USER_MODE
        ];
    }

    @AuraEnabled(Cacheable=true scope='global')
    public static Map<String, Object> getProductMetrics() {
        Map<String, Object> metrics = new Map<String, Object>();
        
        // Aggregate queries for metrics
        AggregateResult[] categoryStats = [
            SELECT Category__c, COUNT(Id) productCount, AVG(MSRP__c) avgPrice, MIN(MSRP__c) minPrice, MAX(MSRP__c) maxPrice
            FROM Product__c
            WHERE Category__c != null
            WITH USER_MODE
            GROUP BY Category__c
            ORDER BY COUNT(Id) DESC
        ];
        
        AggregateResult[] materialStats = [
            SELECT Material__c, COUNT(Id) productCount, AVG(MSRP__c) avgPrice
            FROM Product__c
            WHERE Material__c != null
            WITH USER_MODE
            GROUP BY Material__c
            ORDER BY COUNT(Id) DESC
        ];
        
        AggregateResult[] levelStats = [
            SELECT Level__c, COUNT(Id) productCount, AVG(MSRP__c) avgPrice
            FROM Product__c
            WHERE Level__c != null
            WITH USER_MODE
            GROUP BY Level__c
            ORDER BY COUNT(Id) DESC
        ];
        
        // Overall product statistics
        AggregateResult[] overallStats = [
            SELECT COUNT(Id) totalProducts, AVG(MSRP__c) avgPrice, MIN(MSRP__c) minPrice, MAX(MSRP__c) maxPrice
            FROM Product__c
            WITH USER_MODE
        ];
        
        metrics.put('categoryStats', categoryStats);
        metrics.put('materialStats', materialStats);
        metrics.put('levelStats', levelStats);
        metrics.put('overallStats', overallStats);
        
        return metrics;
    }
}
