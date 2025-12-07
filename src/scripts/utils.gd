extends Node
class_name Utils

static func commafy(input_number : int) -> String:
	var number_as_string : String = str(input_number)
	var output_string : String = ""
	var last_index : int = number_as_string.length() - 1
	var count : int = 0

	# Iterate through the string from right to left
	for i in range(last_index, -1, -1):
		output_string = number_as_string[i] + output_string
		count += 1
		# Add a comma every three digits, unless it's the beginning of the number
		if count % 3 == 0 and i != 0:
			output_string = "," + output_string
	return output_string
