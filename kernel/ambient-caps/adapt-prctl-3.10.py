import sys
from pathlib import Path
# usage: adapt-prctl-3.10.py <kernel tree>
p=Path(sys.argv[1])/'security/commoncap.c'; s=p.read_text()
start=s.index('\tcase PR_CAP_AMBIENT:\n'); end=s.index('\tdefault:\n\t\t/* No functionality available', start)
new='''	case PR_CAP_AMBIENT:
		/* 3.10 style: 'new' was prepared above and is committed at
		 * 'changed' or released at 'no_change'/'error'. */
		error = -EINVAL;
		if (arg2 == PR_CAP_AMBIENT_CLEAR_ALL) {
			if (arg3 | arg4 | arg5)
				goto error;
			cap_clear(new->cap_ambient);
			goto changed;
		}

		if (((!cap_valid(arg3)) | arg4 | arg5))
			goto error;

		if (arg2 == PR_CAP_AMBIENT_IS_SET) {
			error = !!cap_raised(new->cap_ambient, arg3);
			goto no_change;
		} else if (arg2 != PR_CAP_AMBIENT_RAISE &&
			   arg2 != PR_CAP_AMBIENT_LOWER) {
			goto error;
		}

		if (arg2 == PR_CAP_AMBIENT_RAISE &&
		    (!cap_raised(new->cap_permitted, arg3) ||
		     !cap_raised(new->cap_inheritable, arg3))) {
			error = -EPERM;
			goto error;
		}
		if (arg2 == PR_CAP_AMBIENT_RAISE)
			cap_raise(new->cap_ambient, arg3);
		else
			cap_lower(new->cap_ambient, arg3);
		goto changed;

'''
p.write_text(s[:start]+new+s[end:])
print('rewrote PR_CAP_AMBIENT case')
