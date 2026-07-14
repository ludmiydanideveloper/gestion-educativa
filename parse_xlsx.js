const XLSX = require('xlsx');
const path = require('path');

const file = 'C:\\Users\\Administrador\\Downloads\\Horario Secundario Marzo 2026.xlsx';
const workbook = XLSX.readFile(file);
console.log("Sheet names in Excel workbook:", workbook.SheetNames);
