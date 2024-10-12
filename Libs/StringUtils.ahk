
class StringUtils
{
	static Replicate(input, count)
	{
		if (count <= 0)
		{
			return input
		}
		
		return StrReplace(Format("{:" count "}","")," ", input)
	}
}

class ClipboardUtils
{
}

