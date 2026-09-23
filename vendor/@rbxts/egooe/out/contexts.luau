local Runtime = require(script.Parent.Runtime)

return {
	scrollX = Runtime.createContext("scrollX"),
	tableState = Runtime.createContext("tableState"),
	tableRowState = Runtime.createContext("tableRowState"),
	tableCellState = Runtime.createContext("tableCellState"),
}
