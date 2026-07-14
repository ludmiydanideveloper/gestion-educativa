const XLSX = require('xlsx');

const file = 'C:\\Users\\Administrador\\Downloads\\Horario Secundario Marzo 2026.xlsx';
const workbook = XLSX.readFile(file);
const sheet = workbook.Sheets['Hoja1'];
const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });

console.log("=== Dumping Hoja1 ===");
data.forEach((row, i) => {
  if (row.some(val => val !== null && val !== undefined)) {
    console.log(`Row ${i + 1}:`, row);
  }
});
