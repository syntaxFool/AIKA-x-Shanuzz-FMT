// Google Apps Script Backend for AIKA x Shanuzz FMT
// Deploy this as a Web App with "Execute as: Me" and "Who has access: Anyone"

// Configuration
const SPREADSHEET_ID = '1e2Zt5EsUvdAXzlHigNwsT8EmytJXV7mXwuP1vY-378Q';
const RAW_TABLE_SHEET_NAME = 'rawtable';
const USER_SHEET_NAME = 'user';

// Main entry point for GET requests
function doGet(e) {
  try {
    const action = e.parameter.action;
    
    switch(action) {
      case 'getRawTable':
        return getRawTableEntries();
      case 'getUsers':
        return getUsers();
      case 'getUserByToken':
        return getUserByToken(e.parameter.token);
      default:
        return createResponse(false, 'Invalid action');
    }
  } catch (error) {
    return createResponse(false, error.toString());
  }
}

// Main entry point for POST requests
function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    const action = data.action;
    
    switch(action) {
      case 'addRawTable':
        return addRawTableEntry(data.data);
      case 'updateRawTable':
        return updateRawTableEntry(data.reffid, data.data);
      case 'deleteRawTable':
        return deleteRawTableEntry(data.reffid);
      case 'addUser':
        return addUser(data.data);
      case 'updateUser':
        return updateUser(data.reffid, data.data);
      case 'deleteUser':
        return deleteUser(data.reffid);
      default:
        return createResponse(false, 'Invalid action');
    }
  } catch (error) {
    return createResponse(false, error.toString());
  }
}

// Helper function to create JSON response
function createResponse(success, data, message = '') {
  const response = {
    success: success,
    data: data,
    message: message
  };
  
  return ContentService
    .createTextOutput(JSON.stringify(response))
    .setMimeType(ContentService.MimeType.JSON);
}

// Get spreadsheet
function getSpreadsheet() {
  return SpreadsheetApp.openById(SPREADSHEET_ID);
}

// ========== RAW TABLE OPERATIONS ==========

// Get all raw table entries
function getRawTableEntries() {
  const sheet = getSpreadsheet().getSheetByName(RAW_TABLE_SHEET_NAME);
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const rows = data.slice(1);
  
  const entries = rows.map(row => {
    const entry = {};
    headers.forEach((header, index) => {
      entry[header] = row[index];
    });
    return entry;
  });
  
  return createResponse(true, entries);
}

// Add raw table entry
function addRawTableEntry(entryData) {
  const sheet = getSpreadsheet().getSheetByName(RAW_TABLE_SHEET_NAME);
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  
  const row = headers.map(header => entryData[header] || '');
  sheet.appendRow(row);
  
  return createResponse(true, 'Entry added successfully');
}

// Update raw table entry
function updateRawTableEntry(reffid, entryData) {
  const sheet = getSpreadsheet().getSheetByName(RAW_TABLE_SHEET_NAME);
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const reffidIndex = headers.indexOf('Reffid');
  
  for (let i = 1; i < data.length; i++) {
    if (data[i][reffidIndex] === reffid) {
      const row = headers.map(header => entryData[header] || '');
      sheet.getRange(i + 1, 1, 1, headers.length).setValues([row]);
      return createResponse(true, 'Entry updated successfully');
    }
  }
  
  return createResponse(false, 'Entry not found');
}

// Delete raw table entry
function deleteRawTableEntry(reffid) {
  const sheet = getSpreadsheet().getSheetByName(RAW_TABLE_SHEET_NAME);
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const reffidIndex = headers.indexOf('Reffid');
  
  for (let i = 1; i < data.length; i++) {
    if (data[i][reffidIndex] === reffid) {
      sheet.deleteRow(i + 1);
      return createResponse(true, 'Entry deleted successfully');
    }
  }
  
  return createResponse(false, 'Entry not found');
}

// ========== USER OPERATIONS ==========

// Get all users
function getUsers() {
  const sheet = getSpreadsheet().getSheetByName(USER_SHEET_NAME);
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const rows = data.slice(1);
  
  const users = rows.map(row => {
    const user = {};
    headers.forEach((header, index) => {
      user[header] = row[index];
    });
    return user;
  });
  
  return createResponse(true, users);
}

// Get user by token
function getUserByToken(token) {
  const sheet = getSpreadsheet().getSheetByName(USER_SHEET_NAME);
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const tokenIndex = headers.indexOf('Token');
  
  for (let i = 1; i < data.length; i++) {
    if (data[i][tokenIndex] === token) {
      const user = {};
      headers.forEach((header, index) => {
        user[header] = data[i][index];
      });
      return createResponse(true, user);
    }
  }
  
  return createResponse(false, null, 'User not found');
}

// Add user
function addUser(userData) {
  const sheet = getSpreadsheet().getSheetByName(USER_SHEET_NAME);
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  
  const row = headers.map(header => userData[header] || '');
  sheet.appendRow(row);
  
  return createResponse(true, 'User added successfully');
}

// Update user
function updateUser(reffid, userData) {
  const sheet = getSpreadsheet().getSheetByName(USER_SHEET_NAME);
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const reffidIndex = headers.indexOf('Reffid');
  
  for (let i = 1; i < data.length; i++) {
    if (data[i][reffidIndex] === reffid) {
      const row = headers.map(header => userData[header] || '');
      sheet.getRange(i + 1, 1, 1, headers.length).setValues([row]);
      return createResponse(true, 'User updated successfully');
    }
  }
  
  return createResponse(false, 'User not found');
}

// Delete user
function deleteUser(reffid) {
  const sheet = getSpreadsheet().getSheetByName(USER_SHEET_NAME);
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const reffidIndex = headers.indexOf('Reffid');
  
  for (let i = 1; i < data.length; i++) {
    if (data[i][reffidIndex] === reffid) {
      sheet.deleteRow(i + 1);
      return createResponse(true, 'User deleted successfully');
    }
  }
  
  return createResponse(false, 'User not found');
}

// Test function to verify setup
function testSetup() {
  Logger.log('Testing spreadsheet access...');
  const ss = getSpreadsheet();
  Logger.log('Spreadsheet name: ' + ss.getName());
  
  const rawTableSheet = ss.getSheetByName(RAW_TABLE_SHEET_NAME);
  Logger.log('Raw Table Sheet: ' + (rawTableSheet ? 'Found' : 'Not Found'));
  
  const userSheet = ss.getSheetByName(USER_SHEET_NAME);
  Logger.log('User Sheet: ' + (userSheet ? 'Found' : 'Not Found'));
  
  Logger.log('Setup test completed!');
}
