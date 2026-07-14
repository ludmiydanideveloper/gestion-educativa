const XLSX = require('xlsx');

const file = 'C:\\Users\\Administrador\\Downloads\\Horario Secundario Marzo 2026.xlsx';
const workbook = XLSX.readFile(file);

workbook.SheetNames.forEach(sheetName => {
  console.log(`===============================================`);
  console.log(`Sheet: ${sheetName}`);
  const sheet = workbook.Sheets[sheetName];
  const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });
  console.log(`Total rows: ${data.length}`);
  console.log("First 15 rows:");
  data.slice(0, 15).forEach((row, i) => {
    console.log(`Row ${i + 1}:`, row);
  });
});
