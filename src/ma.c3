module ma;

faultdef
    AT_END_REACHED,
    FAILED;

$assert AllocationCallbacks::size == 32;
$assert Format.F32.ordinal == 5;

<*
 Turn a miniaudio result code into a fault.
 @return? AT_END_REACHED, FAILED
*>
fn void? check(Result result) {
    switch (result) {
        case SUCCESS:
            return;
        case AT_END:
            return AT_END_REACHED~;
        default:
            return FAILED~;
    }
}

<*
 Byte stride of an object of the given size when stored in a table.
*>
fn usz stride(usz object_size) {
    usz alignment = object_alignment();
    return (object_size + alignment - 1) / alignment * alignment;
}
