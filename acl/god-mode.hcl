acl = "write"
agent_prefix "" {
	policy = "write"
}
event_prefix "" {
	policy = "write"
}
key_prefix "" {
	policy = "write"
}
keyring = "write"
node_prefix "" {
	policy = "write"
}
operator = "write"
mesh = "write"
peering = "write"
query_prefix "" {
	policy = "write"
}
service_prefix "" {
	policy = "write"
	intentions = "write"
}
session_prefix "" {
	policy = "write"
}
partition_prefix "" {
	mesh = "write"
	peering = "write"
	namespace "default" {
		node_prefix "" {
			policy = "write"
		}
		agent_prefix "" {
			policy = "write"
		}
	}
	namespace_prefix "" {
		acl = "write"
		key_prefix "" {
			policy = "write"
		}
		node_prefix "" {
			# node policy is restricted to read within a namespace
			policy = "read"
		}
		session_prefix "" {
			policy = "write"
		}
		service_prefix "" {
			policy = "write"
			intentions = "write"
		}
	}
}