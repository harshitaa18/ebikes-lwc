import { LightningElement, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { reduceErrors } from 'c/ldsUtils';

/** Record DML operations. */
import {
    createRecord,
    updateRecord,
    deleteRecord
} from 'lightning/uiRecordApi';

/** Use Apex to fetch related records. */
import { refreshApex, getSObjectValue } from '@salesforce/apex';
import getOrderItems from '@salesforce/apex/OrderController.getOrderItems';
import createOrderItem from '@salesforce/apex/OrderController.createOrderItem';
import updateOrderItem from '@salesforce/apex/OrderController.updateOrderItem';
import deleteOrderItem from '@salesforce/apex/OrderController.deleteOrderItem';
import getOrderMetrics from '@salesforce/apex/OrderController.getOrderMetrics';
import trackMetricEvent from '@salesforce/apex/MetricsCollector.trackMetricEvent';

/** Order_Item__c Schema. */
import ORDER_ITEM_OBJECT from '@salesforce/schema/Order_Item__c';
import ORDER_FIELD from '@salesforce/schema/Order_Item__c.Order__c';
import PRODUCT_FIELD from '@salesforce/schema/Order_Item__c.Product__c';
import QTY_SMALL_FIELD from '@salesforce/schema/Order_Item__c.Qty_S__c';
import QTY_MEDIUM_FIELD from '@salesforce/schema/Order_Item__c.Qty_M__c';
import QTY_LARGE_FIELD from '@salesforce/schema/Order_Item__c.Qty_L__c';
import PRICE_FIELD from '@salesforce/schema/Order_Item__c.Price__c';

/** Order_Item__c Schema. */
import PRODUCT_MSRP_FIELD from '@salesforce/schema/Product__c.MSRP__c';

/** Discount for resellers. TODO - move to custom field on Account. */
const DISCOUNT = 0.6;

/**
 * Gets the quantity of all items in an Order_Item__c SObject.
 */
function getQuantity(orderItem) {
    return (
        getSObjectValue(orderItem, QTY_SMALL_FIELD) +
        getSObjectValue(orderItem, QTY_MEDIUM_FIELD) +
        getSObjectValue(orderItem, QTY_LARGE_FIELD)
    );
}

/**
 * Gets the price for the specified quantity of Order_Item__c SObject.
 */
function getPrice(orderItem, quantity) {
    return getSObjectValue(orderItem, PRICE_FIELD) * quantity;
}

/**
 * Calculates the quantity and price of all Order_Item__c SObjects.
 */
function calculateOrderSummary(orderItems) {
    const summary = orderItems.reduce(
        (acc, orderItem) => {
            const quantity = getQuantity(orderItem);
            const price = getPrice(orderItem, quantity);
            acc.quantity += quantity;
            acc.price += price;
            return acc;
        },
        { quantity: 0, price: 0 }
    );
    return summary;
}

/**
 * Builds Order__c by CRUD'ing the related Order_Item__c SObjects.
 */
export default class OrderBuilder extends LightningElement {
    /** Id of Order__c SObject to display. */
    @api recordId;

    /** The Order_Item__c SObjects to display. */
    orderItems;

    /** Total price of the Order__c. Calculated from this.orderItems. */
    orderPrice = 0;

    /** Total quantity of the Order__c. Calculated from this.orderItems. */
    orderQuantity = 0;

    /** Order metrics data */
    orderMetrics;

    error;

    /** Wired Apex result so it may be programmatically refreshed. */
    wiredOrderItems;

    /** Wired order metrics result */
    wiredOrderMetrics;

    /** Apex load the Order__c's Order_Item_c[] and their related Product__c details. */
    @wire(getOrderItems, { orderId: '$recordId' })
    wiredGetOrderItems(value) {
        this.wiredOrderItems = value;
        if (value.error) {
            this.error = value.error;
        } else if (value.data) {
            this.setOrderItems(value.data);
        }
    }

    /** Wire method for order metrics */
    @wire(getOrderMetrics, { orderId: '$recordId' })
    wiredGetOrderMetrics(value) {
        this.wiredOrderMetrics = value;
        if (value.error) {
            this.error = value.error;
        } else if (value.data) {
            this.orderMetrics = value.data;
        }
    }

    /** Updates the order items, recalculating the order quantity and price. */
    setOrderItems(orderItems) {
        this.orderItems = orderItems.slice();
        const summary = calculateOrderSummary(this.orderItems);
        this.orderQuantity = summary.quantity;
        this.orderPrice = summary.price;
    }

    /** Handles drag-and-dropping a new product to create a new Order_Item__c. */
    handleDrop(event) {
        event.preventDefault();
        // Product__c from LDS
        const product = JSON.parse(event.dataTransfer.getData('product'));

        // Use new Apex method for DML operation
        const price = Math.round(getSObjectValue(product, PRODUCT_MSRP_FIELD) * DISCOUNT);
        
        createOrderItem({
            orderId: this.recordId,
            productId: product.Id,
            price: price,
            qtyS: 0,
            qtyM: 0,
            qtyL: 0
        })
        .then((result) => {
            // Track metric event
            trackMetricEvent({
                metricType: 'ORDER_ITEM_CREATED',
                recordId: result.Id,
                value: price
            }).catch(() => {
                // Ignore metric tracking errors
            });
            
            // refresh the Order_Item__c SObjects
            return refreshApex(this.wiredOrderItems);
        })
        .catch((e) => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error creating order',
                    message: reduceErrors(e).join(', '),
                    variant: 'error'
                })
            );
        });
    }

    /** Handles for dragging events. */
    handleDragOver(event) {
        event.preventDefault();
    }

    /** Handles event to change Order_Item__c details. */
    handleOrderItemChange(evt) {
        const orderItemChanges = evt.detail;

        // optimistically make the change on the client
        const previousOrderItems = this.orderItems;
        const orderItems = this.orderItems.map((orderItem) => {
            if (orderItem.Id === orderItemChanges.Id) {
                // synthesize a new Order_Item__c SObject
                return Object.assign({}, orderItem, orderItemChanges);
            }
            return orderItem;
        });
        this.setOrderItems(orderItems);

        // Use new Apex method for DML operation
        updateOrderItem({
            orderItemId: orderItemChanges.Id,
            price: orderItemChanges.Price__c,
            qtyS: orderItemChanges.Qty_S__c,
            qtyM: orderItemChanges.Qty_M__c,
            qtyL: orderItemChanges.Qty_L__c
        })
        .then((result) => {
            // Track metric event
            trackMetricEvent({
                metricType: 'ORDER_ITEM_UPDATED',
                recordId: result.Id,
                value: result.Price__c
            }).catch(() => {
                // Ignore metric tracking errors
            });
        })
        .catch((e) => {
            // error updating server so rollback to previous data
            this.setOrderItems(previousOrderItems);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error updating order item',
                    message: reduceErrors(e).join(', '),
                    variant: 'error'
                })
            );
        });
    }

    /** Handles event to delete Order_Item__c. */
    handleOrderItemDelete(evt) {
        const id = evt.detail.id;

        // optimistically make the change on the client
        const previousOrderItems = this.orderItems;
        const orderItems = this.orderItems.filter(
            (orderItem) => orderItem.Id !== id
        );
        this.setOrderItems(orderItems);

        // Use new Apex method for DML operation
        deleteOrderItem({ orderItemId: id })
        .then(() => {
            // Track metric event
            trackMetricEvent({
                metricType: 'ORDER_ITEM_DELETED',
                recordId: id,
                value: 0
            }).catch(() => {
                // Ignore metric tracking errors
            });
        })
        .catch((e) => {
            // error updating server so rollback to previous data
            this.setOrderItems(previousOrderItems);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error deleting order item',
                    message: reduceErrors(e).join(', '),
                    variant: 'error'
                })
            );
        });
    }

    get hasNoOrderItems() {
        return this.orderItems.length === 0;
    }
}
