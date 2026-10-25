extends TestCase


func test_runner_works() -> void:
	assert_eq(1 + 1, 2)
	assert_near(0.1 + 0.2, 0.3, 1e-9)
	assert_between(5.0, 1.0, 10.0)
