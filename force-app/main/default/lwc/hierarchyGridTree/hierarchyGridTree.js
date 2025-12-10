/**
 * @description       : Generic component to display a hierarchical tree grid for any SObject.
 * @file              : hierarchyGridTree.js
 * @created by        : Tyler Class
 * @created date      : 12/10/2025
 * @version           : 1
 * 
 * @api recordId           : ID of the starting record.
 * @api objectApiName      : API name of the SObject (e.g., Account, Custom__c).
 * @api parentFieldApiName : API name of the parent lookup field (e.g., ParentId).
 * @api title              : Title for the component.
 * @api fieldList          : Comma-separated list of fields to include in the grid.
 */

import { LightningElement, track, api, wire } from 'lwc';
import getHierarchicalRecords from '@salesforce/apex/HierarchicalRecordController.getHierarchicalRecords';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';

export default class HierarchyGridTree extends LightningElement {
    @track treeData = [];
    @track error;
    @track isLoading = true;

    @api recordId;
    @api objectApiName;
    @api parentFieldApiName = 'ParentId';
    @api title = 'Record Hierarchy';
    @api fieldList;

    buttonMsg = 'Expand All';
    buttonVariant = 'Brand';
    finalFields = {};
    gridColumns = [];

    /** Button label for expand/collapse */
    get buttonLabel() {
        return `Click Here to ${this.buttonMsg} Rows`;
    }

    /** Dynamically generate grid columns based on field metadata */
    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    objectInfo({ error, data }) {
        if (data && this.fieldList) {
            this.gridColumns = this.fieldList.map((fieldApiName, index) => {
                const field = data.fields[fieldApiName];
                if (!field) return null;

                let column = {
                    label: field.label,
                    fieldName: fieldApiName,
                    cellAttributes: index === 0 ? {
                        iconName: { fieldName: 'isCurrentRecord' },
                        iconPosition: 'left',
                        iconAlternativeText: 'Current Record',
                    } : {},
                };

                // Relationship field
                if (field.dataType === 'Reference') {
                    this.finalFields[fieldApiName] = `${field.relationshipName}.Name`;
                    column = {
                        ...column,
                        fieldName: `${fieldApiName}_link`,
                        type: 'url',
                        typeAttributes: {
                            label: { fieldName: `${field.relationshipName}Name` },
                            url: { fieldName: `${fieldApiName}_link` },
                            target: '_blank'
                        }
                    };
                }

                // Name field link
                if (fieldApiName.toLowerCase() === 'name') {
                    column = {
                        ...column,
                        fieldName: 'Name_link',
                        type: 'url',
                        typeAttributes: {
                            label: { fieldName: 'Name' },
                            url: { fieldName: 'RecordId_link' },
                            target: '_blank'
                        }
                    };
                }

                return column;
            }).filter(col => col);
        } else if (error) {
            console.error('Error retrieving object info:', error);
        }
    }

    /** Lifecycle: normalize fieldList, add parent field, trigger record fetch */
    connectedCallback() {
        if (!this.fieldList) {
            this.fieldList = ['Name', this.parentFieldApiName];
        } else if (typeof this.fieldList === 'string') {
            this.fieldList = this.fieldList.split(',').map(f => f.trim());
        }

        if (!this.fieldList.includes(this.parentFieldApiName)) {
            this.fieldList.push(this.parentFieldApiName);
        }

        this.getParentAndChildRecords();
    }

    /** Call Apex to fetch records */
    async getParentAndChildRecords() {
        try {
            const recordData = await getHierarchicalRecords({
                objectName: this.objectApiName,
                recordId: this.recordId,
                fields: this.fieldList,
                parentFieldAPI: this.parentFieldApiName
            });

            if (recordData) this.formatTreeData(recordData);
        } catch (error) {
            this.error = error;
            console.error('Error in Apex:', error);
        } finally {
            this.isLoading = false;
        }
    }

    /** Format raw Apex records into tree grid structure */
    formatTreeData(records) {
        const instanceUrl = window.location.origin;
        const recordMap = {};

        for (let rec of records) {
            const copy = { ...rec };

            // Build lookup field links
            for (const [field, relationshipPath] of Object.entries(this.finalFields)) {
                const [relObj, relField] = relationshipPath.split('.');
                copy[`${field}_link`] = copy[field] ? `${instanceUrl}/${copy[field]}` : '';
                copy[`${relObj}Name`] = copy[relObj]?.[relField] || '';
            }

            // Name field link
            if (copy.Name) {
                copy.Name_link = `${instanceUrl}/${copy.Id}`;
                copy.RecordId_link = `${instanceUrl}/${copy.Id}`;
            }

            // Current record icon
            if (copy.Id === this.recordId) {
                copy.isCurrentRecord = 'standard:choice';
            }

            recordMap[copy.Id] = copy;
        }

        // Organize hierarchy
        for (let rec of records) {
            const formatted = recordMap[rec.Id];
            const parentId = formatted?.[this.parentFieldApiName];

            if (parentId && recordMap[parentId]) {
                if (!recordMap[parentId]._children) recordMap[parentId]._children = [];
                recordMap[parentId]._children.push(formatted);
            } else {
                this.treeData.push(formatted);
            }
        }
    }

    /** Whether to render the tree */
    get hasData() {
        return this.treeData.length > 0;
    }

    /** Toggle expand/collapse all rows */
    clickToExpandAll() {
        const grid = this.template.querySelector('lightning-tree-grid');
        if (!grid) return;

        if (this.buttonMsg === 'Expand All') {
            grid.expandAll();
            this.buttonMsg = 'Collapse All';
            this.buttonVariant = 'Neutral';
        } else {
            grid.collapseAll();
            this.buttonMsg = 'Expand All';
            this.buttonVariant = 'Brand';
        }
    }
}