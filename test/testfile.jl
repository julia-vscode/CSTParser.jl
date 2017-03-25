:(let
	$wrapper
	do_threadcall(wrapper, $rettype, Any[$(argtypes...)], Any[$(argvals...)])
end)