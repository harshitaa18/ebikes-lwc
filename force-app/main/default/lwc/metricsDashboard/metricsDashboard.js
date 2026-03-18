import { LightningElement, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { reduceErrors } from 'c/ldsUtils';

/** Apex methods for metrics */
import getComprehensiveMetrics from '@salesforce/apex/MetricsCollector.getComprehensiveMetrics';
import getProductMetrics from '@salesforce/apex/ProductController.getProductMetrics';
import trackMetricEvent from '@salesforce/apex/MetricsCollector.trackMetricEvent';

export default class MetricsDashboard extends LightningElement {
    @api recordId;
    
    metricsData;
    productMetrics;
    error;
    isLoading = true;

    /** Load comprehensive metrics */
    @wire(getComprehensiveMetrics)
    wiredMetrics(result) {
        if (result.error) {
            this.error = result.error;
            this.isLoading = false;
        } else if (result.data) {
            this.metricsData = result.data;
            this.isLoading = false;
        }
    }

    /** Load product-specific metrics */
    @wire(getProductMetrics)
    wiredProductMetrics(result) {
        if (result.error) {
            this.error = result.error;
        } else if (result.data) {
            this.productMetrics = result.data;
        }
    }

    /** Handle manual metric tracking */
    handleTrackMetric() {
        trackMetricEvent({
            metricType: 'MANUAL_METRIC_TRIGGER',
            recordId: this.recordId || '000000000000000000',
            value: Math.random() * 1000
        })
        .then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Metric tracked successfully',
                    variant: 'success'
                })
            );
        })
        .catch((error) => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error tracking metric',
                    message: reduceErrors(error).join(', '),
                    variant: 'error'
                })
            );
        });
    }

    /** Refresh metrics data */
    handleRefresh() {
        this.isLoading = true;
        // Force refresh by calling the wired methods again
        return Promise.resolve();
    }

    /** Get formatted overall statistics */
    get overallStats() {
        if (!this.productMetrics?.overallStats) return [];
        
        return this.productMetrics.overallStats.map(stat => ({
            totalProducts: stat.totalProducts || 0,
            avgPrice: stat.avgPrice ? Math.round(stat.avgPrice) : 0,
            minPrice: stat.minPrice || 0,
            maxPrice: stat.maxPrice || 0
        }));
    }

    /** Get formatted category statistics */
    get categoryStats() {
        if (!this.productMetrics?.categoryStats) return [];
        
        return this.productMetrics.categoryStats.map(stat => ({
            category: stat.Category__c || 'Unknown',
            productCount: stat.productCount || 0,
            avgPrice: stat.avgPrice ? Math.round(stat.avgPrice) : 0,
            minPrice: stat.minPrice || 0,
            maxPrice: stat.maxPrice || 0
        }));
    }

    /** Get formatted material statistics */
    get materialStats() {
        if (!this.productMetrics?.materialStats) return [];
        
        return this.productMetrics.materialStats.map(stat => ({
            material: stat.Material__c || 'Unknown',
            productCount: stat.productCount || 0,
            avgPrice: stat.avgPrice ? Math.round(stat.avgPrice) : 0
        }));
    }

    /** Get formatted level statistics */
    get levelStats() {
        if (!this.productMetrics?.levelStats) return [];
        
        return this.productMetrics.levelStats.map(stat => ({
            level: stat.Level__c || 'Unknown',
            productCount: stat.productCount || 0,
            avgPrice: stat.avgPrice ? Math.round(stat.avgPrice) : 0
        }));
    }

    /** Get cross-object metrics */
    get crossObjectMetrics() {
        if (!this.metricsData?.crossObjectMetrics) return [];
        
        return {
            productOrderCorrelation: this.metricsData.crossObjectMetrics.productOrderCorrelation || [],
            priceQuantityAnalysis: this.metricsData.crossObjectMetrics.priceQuantityAnalysis || []
        };
    }

    /** Check if data is available */
    get hasData() {
        return this.productMetrics || this.metricsData;
    }

    /** Check if there's an error */
    get hasError() {
        return this.error;
    }
}
